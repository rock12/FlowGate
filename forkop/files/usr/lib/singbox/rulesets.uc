#!/usr/bin/env ucode

const SRS_MAIN_URL = "https://github.com/itdoginfo/allow-domains/releases/latest/download";
const SRS_ADS_HAGEZI_PRO_URL = "https://github.com/zxc-rv/ad-filter/releases/latest/download/adlist.srs";
const SRS_SUPERCELL_URL = "https://raw.githubusercontent.com/ushan0v/sing-box-supercell-ruleset/main/supercell.srs";
const SRS_GITHUB_URL = "https://raw.githubusercontent.com/MetaCubeX/meta-rules-dat/sing/geo/geosite/github.srs";

const COMMUNITY_SERVICES = {
    russia_inside: true,
    russia_outside: true,
    ukraine_inside: true,
    geoblock: true,
    block: true,
    porn: true,
    news: true,
    anime: true,
    youtube: true,
    hdrezka: true,
    tiktok: true,
    google_ai: true,
    google_play: true,
    hodca: true,
    discord: true,
    meta: true,
    twitter: true,
    cloudflare: true,
    cloudfront: true,
    digitalocean: true,
    hetzner: true,
    ovh: true,
    telegram: true,
    roblox: true,
    ads_hagezi_pro: true,
    supercell: true,
    github: true,
    wz_wardogs: true,
    wz_apex: true,
    wz_fortnite: true,
    wz_darksouls: true,
    wz_ru_gaming_all: true,
    wz_activision: true,
    wz_servers: true,
    wz_ea: true,
    wz_xbox: true,
    wz_steam: true,
    wz_download: true,
    wz_torrent: true,
    wz_win_spy: true,
    wz_whitelist: true,
    wz_gemini: true,
    wz_copilot: true,
    wz_adobe: true,
    wz_netflix: true
};

const COMMUNITY_URL_OVERRIDES = {
    ads_hagezi_pro: SRS_ADS_HAGEZI_PRO_URL,
    supercell: SRS_SUPERCELL_URL,
    github: SRS_GITHUB_URL,
    wz_wardogs: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/wardogs.yaml",
    wz_apex: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/apex-legends.yaml",
    wz_fortnite: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/fortnite.yaml",
    wz_darksouls: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/darksouls.yaml",
    wz_ru_gaming_all: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/ru-gaming-all.yaml",
    wz_activision: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/activision.yaml",
    wz_servers: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/warzone-servers.yaml",
    wz_ea: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/ea.yaml",
    wz_xbox: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/Xbox.yaml",
    wz_steam: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/SteamList.list",
    wz_download: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/Download.yaml",
    wz_torrent: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/torrent-domains.mrs",
    wz_win_spy: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/win-spy.mrs",
    wz_whitelist: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/whitelist.mrs",
    wz_gemini: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/Gemini.yaml",
    wz_copilot: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/Copilot.yaml",
    wz_adobe: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/AdobeActivation.yaml",
    wz_netflix: "https://raw.githubusercontent.com/rock12/clash-warzone-rules/main/Netflix.yaml"
};

function as_string(value) {
    return value == null ? "" : "" + value;
}

function is_community(name) {
    return COMMUNITY_SERVICES[as_string(name)] === true;
}

function community_url(name) {
    name = as_string(name);
    if (COMMUNITY_URL_OVERRIDES[name])
        return COMMUNITY_URL_OVERRIDES[name];
    return SRS_MAIN_URL + "/" + name + ".srs";
}

function hash12(value) {
    value = as_string(value);
    let first = 2166136261;
    let second = 16777619;

    for (let i = 0; i < length(value); i++) {
        let code = ord(substr(value, i, 1));
        first = (first * 33 + code) % 4294967296;
        second = (second * 131 + code) % 4294967296;
    }

    return sprintf("%06x%06x", first % 16777216, second % 16777216);
}

function file_extension(value) {
    let basename = as_string(value);
    let slash = rindex(basename, "/");
    if (slash >= 0)
        basename = substr(basename, slash + 1);

    let query = index(basename, "?");
    if (query >= 0)
        basename = substr(basename, 0, query);

    let fragment = index(basename, "#");
    if (fragment >= 0)
        basename = substr(basename, 0, fragment);

    let dot = rindex(basename, ".");
    return dot >= 0 ? lc(substr(basename, dot + 1)) : "";
}

function kind_from_reference_hint(reference) {
    reference = lc(as_string(reference));
    if (index(reference, "geosite") >= 0 || index(reference, "domain") >= 0 ||
        index(reference, "domains") >= 0 || index(reference, "adguard") >= 0 ||
        index(reference, "filter") >= 0)
        return "domains";
    if (index(reference, "geoip") >= 0 || index(reference, "subnet") >= 0 ||
        index(reference, "subnets") >= 0 || index(reference, "cidr") >= 0)
        return "subnets";
    return "unknown";
}

function remote_format(reference) {
    return file_extension(reference) == "json" ? "source" : "binary";
}

function module_exports() {
    return {
        is_community,
        community_url,
        hash12,
        file_extension,
        kind_from_reference_hint,
        remote_format
    };
}

if ((sourcepath(1) != null && sourcepath(1) != "") || ARGV[0] == null)
    return module_exports();

let mode = ARGV[0] || "";

if (mode == "file-extension")
    print(file_extension(ARGV[1]), "\n");
else if (mode == "is-community")
    exit(is_community(ARGV[1]) ? 0 : 1);
else if (mode == "kind-from-reference-hint")
    print(kind_from_reference_hint(ARGV[1]), "\n");
else if (mode == "remote-format")
    print(remote_format(ARGV[1]), "\n");
else {
    warn("Usage: singbox/rulesets.uc <file-extension|is-community|kind-from-reference-hint|remote-format> ...\n");
    exit(1);
}
