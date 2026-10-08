#!/usr/bin/env ucode

let fs = require("fs");
let common = require("core.common");
let uci = require("uci");
let constants = require("core.constants");
let smart_detect = require("service.smart_detect");
let smart_plus = require("service.smart_detect_plus");

let as_string = common.as_string;
let shell_quote = common.shell_quote;

const CONFIG_NAME = getenv("FORKOP_CONFIG_NAME") || constants.FORKOP_CONFIG_NAME || "forkop";
const LIB_DIR = getenv("FORKOP_LIB") || "/usr/lib/forkop";
const RUNTIME_STATE_DIR = getenv("FORKOP_RUNTIME_STATE_DIR") || "/var/run/forkop";
const PID_FILE = RUNTIME_STATE_DIR + "/smart_detect.pid";
const SEEN_FILE = RUNTIME_STATE_DIR + "/smart_detect_seen.json";
const PLUS_SEEN_FILE = RUNTIME_STATE_DIR + "/smart_detect_plus_seen.json";
const RUNNER_UC = LIB_DIR + "/service/smart_detect_runner.uc";

function log_msg(msg, level) {
    level = level || "info";
    common.command_success_from_args([ "logger", "-t", "flowgate[smart-detect]", "[" + level + "] " + as_string(msg) ]);
}

function process_running(pid) {
    if (pid == null || pid == "") return false;
    pid = int(pid);
    if (pid <= 0) return false;
    return fs.stat("/proc/" + pid) != null;
}

function get_settings() {
    let c = uci.cursor();
    if (!c) return {};
    c.load(CONFIG_NAME);
    return c.get_all(CONFIG_NAME, "settings") || {};
}

function get_proxy_sections() {
    let c = uci.cursor();
    if (!c) return [];
    c.load(CONFIG_NAME);
    let secs = [];
    c.foreach(CONFIG_NAME, "section", function(s) {
        if (s.enabled == "0") return;
        let act = as_string(s.action || "");
        if (act != "bypass" && act != "block" && act != "dns" && act != "") {
            push(secs, s[".name"]);
        }
    });
    return secs;
}

function get_target_section(settings, available_sections) {
    if (length(available_sections) == 0) return null;
    let raw = settings.smart_detect_sections || settings.smart_detect_section;
    let selected = type(raw) == "array" ? raw : (raw ? [raw] : []);
    for (let name in selected) {
        name = trim(as_string(name));
        if (index(available_sections, name) >= 0) return name;
    }
    return available_sections[0];
}

let cached_clash_info = null;
let cached_cfg_mtime = 0;

function get_clash_api_info() {
    let st = fs.stat("/etc/sing-box/config.json");
    if (!st) return { port: 9090, secret: "", proxy_port: 4534 };
    if (cached_clash_info && cached_cfg_mtime == st.mtime)
        return cached_clash_info;
    let data = fs.readfile("/etc/sing-box/config.json");
    let info = { port: 9090, secret: "", proxy_port: 4534 };
    if (data) {
        try {
            let sb_cfg = json(data);
            if (sb_cfg?.experimental?.clash_api) {
                let api = sb_cfg.experimental.clash_api;
                info.secret = as_string(api.secret || "");
                let ext = as_string(api.external_controller || "");
                let m = match(ext, /:([0-9]+)$/);
                if (m) info.port = int(m[1]);
            }
            if (sb_cfg?.inbounds) {
                for (let inb in sb_cfg.inbounds) {
                    if (inb.type == "mixed" || inb.type == "http") {
                        info.proxy_port = int(inb.listen_port || 4534);
                        break;
                    }
                }
            }
        } catch (e) {}
    }
    cached_clash_info = info;
    cached_cfg_mtime = st.mtime;
    return info;
}

function get_proxy_port() {
    return get_clash_api_info().proxy_port;
}

function add_domains_to_section(section_name, domains) {
    if (!section_name || length(domains) == 0) return false;
    let c = uci.cursor();
    if (!c) return false;
    c.load(CONFIG_NAME);
    let sec = c.get_all(CONFIG_NAME, section_name);
    if (!sec) return false;

    let existing = sec.user_domains;
    let existing_list = [];
    if (type(existing) == "array") {
        existing_list = existing;
    } else if (existing && trim(as_string(existing)) != "") {
        existing_list = [ trim(as_string(existing)) ];
    }

    let existing_map = {};
    for (let d in existing_list) {
        existing_map[lc(trim(as_string(d)))] = true;
    }

    // Also check user_domains_text
    let text_val = sec.user_domains_text || "";
    for (let line in split(text_val, /[\r\n]+/)) {
        line = lc(trim(line));
        if (line != "") existing_map[line] = true;
    }

    let added = 0;
    for (let dom in domains) {
        dom = lc(trim(as_string(dom)));
        if (dom == "" || existing_map[dom]) continue;
        c.list_add(CONFIG_NAME, section_name, "user_domains", dom);
        existing_map[dom] = true;
        added++;
        log_msg("Added blocked domain '" + dom + "' to section '" + section_name + "'", "info");
    }

    if (added == 0) return true;

    c.commit(CONFIG_NAME);
    system("/usr/bin/forkop reload >/dev/null 2>&1 &");
    return true;
}

// Direct curl probe bypass args: so router curl doesn't loop into sing-box
function direct_curl_flags() {
    return [ "--interface", "0.0.0.0" ];
}

let pending_streaks = {};
let memory_seen = null;
let memory_seen_modified = false;
let last_seen_prune = 0;

function get_seen() {
    if (memory_seen == null) {
        memory_seen = common.read_json_file(SEEN_FILE) || {};
        if (type(memory_seen) != "object") memory_seen = {};
    }
    let now = time();
    if (now - last_seen_prune >= 30) {
        last_seen_prune = now;
        for (let d in keys(memory_seen)) {
            if (memory_seen[d] < now - 86400) {
                delete memory_seen[d];
                memory_seen_modified = true;
            }
        }
    }
    return memory_seen;
}

function save_seen_if_needed() {
    if (memory_seen_modified && memory_seen != null) {
        common.write_json_file(SEEN_FILE, memory_seen);
        memory_seen_modified = false;
    }
}

let memory_plus_seen = null;
let memory_plus_seen_modified = false;
let last_plus_seen_prune = 0;

function get_plus_seen() {
    if (memory_plus_seen == null) {
        memory_plus_seen = common.read_json_file(PLUS_SEEN_FILE) || {};
        if (type(memory_plus_seen) != "object") memory_plus_seen = {};
    }
    let now = time();
    if (now - last_plus_seen_prune >= 30) {
        last_plus_seen_prune = now;
        for (let d in keys(memory_plus_seen)) {
            if (memory_plus_seen[d] < now - 300) {
                delete memory_plus_seen[d];
                memory_plus_seen_modified = true;
            }
        }
    }
    return memory_plus_seen;
}

function save_plus_seen_if_needed() {
    if (memory_plus_seen_modified && memory_plus_seen != null) {
        common.write_json_file(PLUS_SEEN_FILE, memory_plus_seen);
        memory_plus_seen_modified = false;
    }
}

function run_default_cycle(settings, target_section, proxy_port) {
    let now = time();
    let exclude_ru = settings.smart_detect_exclude_ru != "0";
    let user_excludes = settings.smart_detect_exclude_domains || [];

    let seen = get_seen();

    let log_out = common.command_output_from_args([ "logread", "-l", "120" ]) || "";
    let candidates = {};

    for (let line in split(log_out, "\n")) {
        let ll = lc(line);
        if (index(ll, "direct") < 0 && index(ll, "direct-out") < 0) continue;
        if (index(ll, "failed") < 0 && index(ll, "timeout") < 0 && index(ll, "reset") < 0 && index(ll, "refused") < 0) continue;

        let host = smart_detect.extract_host(line);
        if (!host || seen[host]) continue;
        if (smart_detect.is_protected_domain(host, exclude_ru, user_excludes)) continue;
        candidates[host] = true;
    }
    log_out = null;

    let confirmed_domains = [];
    let proxy_addr = "127.0.0.1:" + proxy_port;

    for (let domain in keys(candidates)) {
        let direct_status = smart_detect.probe_status([
            "curl", "-s", "-I", "-o", "/dev/null", "--connect-timeout", "4", "--max-time", "6",
            "https://" + domain
        ]);
        let direct_kind = smart_detect.probe_kind(direct_status);

        let proxy_kind = "skipped";
        if (direct_kind == "transport" || direct_kind == "dns") {
            let proxy_status = smart_detect.probe_status([
                "curl", "-s", "-I", "-o", "/dev/null", "--connect-timeout", "5", "--max-time", "8",
                "--proxy", "http://" + proxy_addr,
                "https://" + domain
            ]);
            proxy_kind = proxy_status == 0 ? "ok" : smart_detect.probe_kind(proxy_status);
        }

        let dec = smart_detect.verdict(domain, {
            direct: direct_kind,
            proxy: proxy_kind,
            now: now
        }, pending_streaks[domain]);

        if (dec.defer) {
            pending_streaks[domain] = { first_fail: dec.first_fail };
        }
        if (dec.seen) {
            seen[domain] = now;
            memory_seen_modified = true;
            delete pending_streaks[domain];
        }
        if (dec.act) {
            push(confirmed_domains, domain);
            seen[domain] = now;
            memory_seen_modified = true;
        }
    }

    if (length(confirmed_domains) > 0) {
        add_domains_to_section(target_section, confirmed_domains);
    }

    save_seen_if_needed();
}

let plus_tracked_conns = {};
let plus_pending = {};

function run_plus_cycle(settings, target_section, proxy_port) {
    let now = time();
    let exclude_ru = settings.smart_detect_exclude_ru != "0";
    let user_excludes = settings.smart_detect_exclude_domains || [];

    let seen = get_plus_seen();

    let clash_info = get_clash_api_info();
    let secret = settings.yacd_secret_key || clash_info.secret || "";
    let clash_cmd = [
        "curl", "-s", "--connect-timeout", "2", "--max-time", "3",
        "--max-filesize", "524288",
        "http://127.0.0.1:" + clash_info.port + "/connections"
    ];
    if (secret != "") {
        push(clash_cmd, "-H", "Authorization: Bearer " + secret);
    }

    let resp = common.command_output_from_args(clash_cmd);
    if (!resp || resp == "") {
        save_plus_seen_if_needed();
        return;
    }

    let snapshot = null;
    try { snapshot = json(resp); } catch (e) { resp = null; return; }
    resp = null;
    if (type(snapshot?.connections) != "array") return;

    let result = smart_plus.stalled_candidates(plus_tracked_conns, snapshot.connections, now, exclude_ru, user_excludes);
    snapshot = null;
    plus_tracked_conns = result.tracked;

    for (let dom in keys(result.domains)) {
        smart_plus.queue_candidate(plus_pending, {
            domain: dom,
            scheme: result.domains[dom],
            priority: result.priorities[dom]
        }, now, 500, exclude_ru, user_excludes);
    }

    let ordered = smart_plus.queue_order(plus_pending, keys(plus_pending));
    if (length(ordered) == 0) {
        save_plus_seen_if_needed();
        return;
    }

    let target_domain = ordered[0];
    let item = plus_pending[target_domain];
    delete plus_pending[target_domain];

    let proxy_addr = "127.0.0.1:" + proxy_port;
    let dec = smart_plus.probe(target_domain, item, proxy_addr, direct_curl_flags(), smart_detect.probe_status);

    if (dec.act) {
        let main = smart_plus.main_domain(target_domain);
        if (main != null && !smart_detect.is_protected_domain(main, exclude_ru, user_excludes)) {
            add_domains_to_section(target_section, [ main ]);
        }
        seen[target_domain] = now;
        memory_plus_seen_modified = true;
    } else if (dec.seen) {
        seen[target_domain] = now;
        memory_plus_seen_modified = true;
    }

    save_plus_seen_if_needed();
}

function run_smart_detect_iteration() {
    let settings = get_settings();
    if (settings.smart_detect != "1") return;

    let sections = get_proxy_sections();
    if (length(sections) == 0) return;

    let target = get_target_section(settings, sections);
    if (!target) return;

    let port = get_proxy_port();
    let mode = smart_plus.mode(settings);

    if (mode == "plus") {
        run_plus_cycle(settings, target, port);
    } else {
        run_default_cycle(settings, target, port);
    }
}

function worker() {
    log_msg("Smart Detect daemon worker started", "info");
    fs.mkdir(RUNTIME_STATE_DIR);
    fs.writefile(PID_FILE, as_string(getpid()) + "\n");

    while (true) {
        let settings = get_settings();
        if (settings.smart_detect != "1") {
            sleep(15000);
            continue;
        }

        try {
            run_smart_detect_iteration();
        } catch (e) {
            log_msg("Error in smart detect cycle: " + as_string(e), "err");
        }

        let sleep_duration = (smart_plus.mode(settings) == "plus") ? 12000 : 20000;
        sleep(sleep_duration);
    }
}

function stop_runtime() {
    let pid = trim(fs.readfile(PID_FILE) || "");
    if (process_running(pid)) {
        common.command_success_from_args([ "kill", pid ]);
        let wait_limit = 10;
        while (wait_limit > 0 && process_running(pid)) {
            sleep(100);
            wait_limit--;
        }
        if (process_running(pid)) {
            common.command_success_from_args([ "kill", "-9", pid ]);
        }
    }
    fs.unlink(PID_FILE);
    return 0;
}

function start_runtime() {
    let settings = get_settings();
    stop_runtime();
    if (settings.smart_detect != "1") return 0;

    let cmd = common.background_command_with_pid(
        common.command_from_args([ "ucode", "-L", LIB_DIR, RUNNER_UC, "worker" ]),
        ">/dev/null 2>&1",
        ">" + shell_quote(PID_FILE)
    );
    system(cmd);
    log_msg("Smart Detect background service started", "info");
    return 0;
}

function get_status() {
    let pid = trim(fs.readfile(PID_FILE) || "");
    if (process_running(pid)) {
        print("running (pid " + pid + ")\n");
        return 0;
    }
    print("stopped\n");
    return 1;
}

let mode = ARGV[0] || "";
if (mode == "start-runtime")
    exit(start_runtime());
else if (mode == "stop-runtime")
    exit(stop_runtime());
else if (mode == "worker")
    exit(worker());
else if (mode == "run-once") {
    run_smart_detect_iteration();
    exit(0);
}
else if (mode == "status")
    exit(get_status());
else {
    warn("Usage: service/smart_detect_runner.uc <start-runtime|stop-runtime|worker|run-once|status>\n");
    exit(1);
}
