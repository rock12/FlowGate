#!/usr/bin/env ucode

let fs = require("fs");
let uci = require("core.uci");

const CONFIG_NAME = getenv("FORKOP_CONFIG_NAME") || "forkop";
const TABLE = "ForkopTorrServerDirect";
const OUTBOUND_MARK = getenv("NFT_OUTBOUND_MARK") || "0x08000000";

function as_string(value) { return value == null ? "" : "" + value; }

function trim(value) {
    let s = as_string(value);
    let m = match(s, /^[ \t\r\n]*/);
    let start = m ? length(m[0]) : 0;
    let end = length(s);
    while (end > start && match(substr(s, end - 1, 1), /[ \t\r\n]/))
        end--;
    return substr(s, start, end - start);
}

function run_cmd(cmd) {
    return system(cmd + " >/dev/null 2>&1") == 0;
}

function capture_cmd(cmd) {
    let p = fs.popen(cmd + " 2>/dev/null", "r");
    if (!p) return "";
    let data = p.read("all");
    p.close();
    return data == null ? "" : as_string(data);
}

function read_file(path) {
    let v = fs.readfile(path);
    return v == null ? "" : as_string(v);
}

function is_torrserver_cmdline(value) {
    value = lc(replace(as_string(value), /\x00/g, " "));
    return match(value, /(^|[/ ])torrserver([^/ ]*)?( |$)/) != null;
}

function numeric_pid(path) {
    let parts = split(path, "/");
    let pid = length(parts) > 2 ? parts[2] : "";
    return match(pid, /^[0-9]+$/) != null ? pid : "";
}

function process_cgroup(pid) {
    for (let line in split(read_file("/proc/" + pid + "/cgroup"), "\n")) {
        let m = match(line, /^[0-9]+::(\/.+)$/);
        if (m != null) return m[1];
    }
    return "";
}

function valid_cgroup(path) {
    if (match(path, /^\/[A-Za-z0-9_.@:-]+(\/[A-Za-z0-9_.@:-]+)+$/) == null)
        return false;
    return path != "/services" && path != "/system.slice" && path != "/user.slice";
}

let cached_pid = "";

function discover() {
    if (cached_pid != "") {
        let cmdline_path = "/proc/" + cached_pid + "/cmdline";
        if (is_torrserver_cmdline(read_file(cmdline_path))) {
            let path = process_cgroup(cached_pid);
            if (path != "")
                return { running: 1, available: 1, pid: cached_pid, cgroup: path };
            return { running: 1, available: 0, pid: cached_pid, cgroup: path };
        }
        cached_pid = "";
    }

    for (let cmdline_path in fs.glob("/proc/[0-9]*/cmdline")) {
        let pid = numeric_pid(cmdline_path);
        if (pid == "" || !is_torrserver_cmdline(read_file(cmdline_path))) continue;
        cached_pid = pid;
        let path = process_cgroup(pid);
        if (path != "")
            return { running: 1, available: 1, pid, cgroup: path };
        return { running: 1, available: 0, pid, cgroup: path };
    }
    return { running: 0, available: 0, pid: "", cgroup: "" };
}

function enabled() {
    if (!uci.available()) return true;
    let val = trim(uci.get(CONFIG_NAME + ".settings.torrserver_direct"));
    return val == "" || val == "1" || val == "true" || val == "on";
}

function active() {
    let out = capture_cmd("nft list chain inet " + TABLE + " output");
    return index(out, "FlowGate TorrServer Direct") >= 0;
}

function remove_rule() {
    run_cmd("nft delete table inet " + TABLE);
}

function apply_rule(info) {
    if (!info.available) return false;
    let path = substr(info.cgroup, 1);
    let parts = split(path, "/");
    let level = length(parts) > 2 ? 2 : length(parts);
    if (level == 2)
        path = parts[0] + "/" + parts[1];

    remove_rule();
    let ruleset_path = "/tmp/forkop-torrserver-direct.nft";
    let ruleset = "add table inet " + TABLE + "\n" +
        "add chain inet " + TABLE + " output { type route hook output priority -151; policy accept; }\n" +
        "add rule inet " + TABLE + " output socket cgroupv2 level " + level + " \"" + path +
        "\" meta mark set " + OUTBOUND_MARK + " counter comment \"FlowGate TorrServer Direct\"\n";

    if (fs.writefile(ruleset_path, ruleset) == null)
        return false;

    let applied = run_cmd("nft -f " + ruleset_path);
    try { fs.unlink(ruleset_path); } catch (e) {}
    if (!applied || !active()) {
        remove_rule();
        return false;
    }
    return true;
}

function status() {
    let info = discover();
    info.enabled = enabled() ? 1 : 0;
    info.active = active() ? 1 : 0;
    return info;
}

function reconcile() {
    if (!enabled()) {
        remove_rule();
        return 0;
    }
    let info = discover();
    if (!info.available) {
        remove_rule();
        return 1;
    }
    return apply_rule(info) ? 0 : 1;
}

function module_exports() {
    return {
        discover,
        status,
        apply_rule,
        remove_rule,
        reconcile,
        enabled
    };
}

if ((sourcepath(1) != null && sourcepath(1) != "") || ARGV[0] == null)
    return module_exports();

let mode = ARGV[0] || "";
if (mode == "status") {
    print(sprintf("%J", status()), "\n");
    exit(0);
}
else if (mode == "reconcile") {
    exit(reconcile());
}
else if (mode == "remove-rule") {
    remove_rule();
    exit(0);
}
else {
    warn("Usage: service/torrserver.uc <status|reconcile|remove-rule>\n");
    exit(1);
}

