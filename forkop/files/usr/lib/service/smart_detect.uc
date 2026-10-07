// Smart Detect: Self-healing routing helper for FlowGate
// Analyzes direct failures, verifies via proxy, and routes blocked destinations.
let common = require("core.common");
let sb_constants = require("singbox.constants");

let as_string = common.as_string;

const DNS_SETTLE_SECONDS = 30;
const CONFIRM_WINDOW = 120;
const CONFIRM_FAILURES = 2;

// Protected Russian / CIS TLDs and ecosystems that must NEVER be auto-routed to foreign proxies
const PROTECTED_TLD_REGEX = /\.(ru|su|by|kz|рф|xn--p1ai|xn--80aswg|xn--80asehdb)$/i;
const PROTECTED_DOMAINS_REGEX = /(^|\.)(vk|vk-portal|userapi|mail|yandex|yastatic|ya|dzen|rutube|ok|odnoklassniki|sber|sberbank|tbank|tinkoff|alfabank|alfa-bank|vtb|gosuslugi|mos|nalog|cbr|nspk|mirpay|avito|ozon|wildberries|kinopoisk|2gis|hh|raiffeisen|gazprombank)\.(com|net|io|me|app|org|tech)$/i;
const LOCAL_DOMAIN_REGEX = /\.(lan|local|home|internal|arpa|localhost)$/i;

function is_protected_domain(domain, exclude_ru, user_excludes) {
    if (domain == null) return true;
    domain = lc(trim(as_string(domain)));
    if (domain == "" || length(domain) < 3) return true;
    if (match(domain, LOCAL_DOMAIN_REGEX) != null || domain == "localhost") return true;

    // Check national TLDs and major RU services if exclude_ru is enabled (default true)
    if (exclude_ru != false && exclude_ru != "0") {
        if (match(domain, PROTECTED_TLD_REGEX) != null) return true;
        if (match(domain, PROTECTED_DOMAINS_REGEX) != null) return true;
    }

    // Check user-configured exclusions
    if (type(user_excludes) == "array") {
        for (let excl in user_excludes) {
            excl = lc(trim(as_string(excl)));
            if (excl != "" && (domain == excl || index(domain, "." + excl) > 0))
                return true;
        }
    }
    return false;
}

function observe_dns(previous, observation, now) {
    previous = previous || {};
    observation = observation || {};
    let signature = observation.signature;
    let changed = signature != previous.signature || previous.changed_at == null ||
        now < previous.changed_at;
    let changed_at = changed || observation.busy ? now : previous.changed_at;
    return {
        signature,
        changed_at,
        ready: signature != null && !observation.busy && now - changed_at >= DNS_SETTLE_SECONDS
    };
}

function probe_kind(status) {
    status = int(status);
    if (status == 0) return "ok";
    if (status == 5 || status == 6) return "dns";
    // TCP-level failures (DPI reset, timeout, connection refused)
    if (index([7, 28, 35, 52, 55, 56], status) >= 0) return "transport";
    // Failed certificate check / MITM
    if (index([58, 60, 77, 83, 90, 91], status) >= 0) return "transport";
    return "local";
}

function probe_status(args) {
    let status = system(args);
    return status == null ? 255 : (status < 0 ? 128 - int(status) : int(status));
}

const HOST_PATTERNS = [
    /"([a-zA-Z0-9][a-zA-Z0-9.-]{1,60}\.[a-zA-Z]{2,})(:[0-9]+)?"/,
    /outbound connection to ([a-zA-Z0-9][a-zA-Z0-9.-]{1,60}\.[a-zA-Z]{2,}):[0-9]+/,
    /dial [a-z]+ ([a-zA-Z0-9][a-zA-Z0-9.-]{1,60}\.[a-zA-Z]{2,}):[0-9]+/,
    /target[= ]([a-zA-Z0-9][a-zA-Z0-9.-]{1,60}\.[a-zA-Z]{2,})/
];

function host_is_usable(host) {
    if (host == null || length(host) < 4) return false;
    if (index(host, "*") >= 0 || index(host, "?") >= 0) return false;
    if (index(host, "..") >= 0) return false;
    if (index(host, "-") == 0 || substr(host, length(host) - 1) == "-") return false;
    return true;
}

function extract_host(line) {
    if (line == null) return null;
    let text = as_string(line);
    for (let pattern in HOST_PATTERNS) {
        let m = match(text, pattern);
        if (!m || !m[1]) continue;
        if (host_is_usable(m[1])) return m[1];
    }
    return null;
}

const TRACE_PATTERN = /\[([0-9]{6,}) /;

function parse_trace(line) {
    if (line == null) return null;
    let m = match(as_string(line), TRACE_PATTERN);
    return (m && m[1]) ? m[1] : null;
}

const OUTBOUND_PATTERN = /outbound\/[a-zA-Z0-9-]+\[([^\]\s]+)\]/;

function outbound_tag_of(line) {
    if (line == null) return null;
    let m = match(as_string(line), OUTBOUND_PATTERN);
    return (m && m[1]) ? m[1] : null;
}

function new_streak() {
    return { first_fail: null, last_seen: 0 };
}

function verdict(domain, observation, streak) {
    streak = streak || new_streak();
    observation = observation || {};
    let first_fail = streak.first_fail;
    let direct = observation.direct;
    let proxy = observation.proxy;

    if (proxy != "ok") return { act: false, seen: false, defer: true, first_fail: null };
    if (direct == "ok") return { act: false, seen: true, defer: false, first_fail: null };
    if (direct == "local") return { act: false, seen: false, defer: true, first_fail: null };

    if (first_fail == null) {
        return {
            act: false,
            seen: false,
            defer: true,
            first_fail: observation.now != null ? observation.now : null
        };
    }
    if (observation.now != null && observation.now - first_fail < CONFIRM_WINDOW)
        return { act: false, seen: false, defer: true, first_fail: first_fail };

    return { act: true, seen: true, defer: false, first_fail: first_fail };
}

const BYPASS_OUTBOUND_TAGS = {
    [sb_constants.DIRECT_OUTBOUND_TAG]: true,
    [sb_constants.BYPASS_OUTBOUND_TAG]: true,
    [sb_constants.DIRECT_BYPASS_OUTBOUND_TAG]: true
};

function is_bypass_outbound_tag(tag) {
    return tag != null && BYPASS_OUTBOUND_TAGS[tag] === true;
}

const UNTAGGED_DIRECT_PATTERN = /outbound\/direct[^a-zA-Z0-9-]/;

function failure_outbound_is_bypass(line) {
    let tag = outbound_tag_of(line);
    if (tag != null) return is_bypass_outbound_tag(tag);
    return line != null && match(as_string(line), UNTAGGED_DIRECT_PATTERN) != null;
}

return {
    observe_dns,
    probe_kind,
    probe_status,
    extract_host,
    host_is_usable,
    parse_trace,
    outbound_tag_of,
    is_bypass_outbound_tag,
    failure_outbound_is_bypass,
    verdict,
    new_streak,
    is_protected_domain,
    CONFIRM_FAILURES,
    CONFIRM_WINDOW,
    DNS_SETTLE_SECONDS
};
