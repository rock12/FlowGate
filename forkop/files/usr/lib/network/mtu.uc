#!/usr/bin/env ucode

let fs = require("fs");
let uci = require("core.uci");

const CONFIG_NAME = getenv("FORKOP_CONFIG_NAME") || "forkop";
const NFT_TABLE_NAME = getenv("NFT_TABLE_NAME") || "ForkopTable";

function as_string(value) {
    return value == null ? "" : "" + value;
}

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

function is_private_ip(ip_str) {
    ip_str = trim(ip_str);
    if (match(ip_str, /^192\.168\./)) return true;
    if (match(ip_str, /^10\./)) return true;
    if (match(ip_str, /^100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\./)) return true; // CGNAT
    let m = match(ip_str, /^172\.(1[6-9]|2[0-9]|3[0-1])\./);
    if (m != null) return true;
    return false;
}

function get_wan_info() {
    let out = capture_cmd("ubus call network.interface.wan status");
    let ip = "";
    let gw = "";
    let ifname = "";

    try {
        let parsed = json(out);
        if (parsed && type(parsed) == "object") {
            ifname = as_string(parsed.l3_device || parsed.device);
            if (type(parsed["ipv4-address"]) == "array" && length(parsed["ipv4-address"]) > 0)
                ip = as_string(parsed["ipv4-address"][0].address);
            if (type(parsed.route) == "array") {
                for (let r in parsed.route) {
                    if (r.target == "0.0.0.0" && r.nexthop) {
                        gw = as_string(r.nexthop);
                        break;
                    }
                }
            }
        }
    } catch (e) {}

    if (ip == "" || gw == "") {
        let route_out = capture_cmd("ip route show default");
        let m = match(route_out, /default via ([0-9.]+) dev ([^ ]+)/);
        if (m) {
            gw = m[1];
            ifname = m[2];
        }
        if (ifname != "") {
            let ip_out = capture_cmd("ip -4 addr show dev " + ifname);
            let m_ip = match(ip_out, /inet ([0-9.]+)/);
            if (m_ip) ip = m_ip[1];
        }
    }

    return { ip, gw, ifname };
}

function probe_df_ping(buffer_size, target) {
    target = target || "8.8.8.8";
    // -M do: Don't Fragment flag (Linux ping)
    // -c 1: 1 packet
    // -W 1: 1 second timeout
    return run_cmd("ping -c 1 -W 1 -M do -s " + buffer_size + " " + target);
}

function probe_optimal_mtu(target) {
    target = target || "8.8.8.8";

    // Quick checks for common MTUs: 1500 (payload 1472), 1492 (payload 1464)
    if (probe_df_ping(1472, target))
        return 1500;
    if (probe_df_ping(1464, target))
        return 1492;

    // Binary search between 1200 and 1464
    let low = 1200;
    let high = 1464;
    let best_payload = 1200;

    while (low <= high) {
        let mid = int((low + high) / 2);
        if (probe_df_ping(mid, target)) {
            best_payload = mid;
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    return best_payload + 28;
}

function detect() {
    let wan = get_wan_info();
    let is_double_nat = is_private_ip(wan.ip);

    // If double NAT, check hop 2 via traceroute
    let hop2_ip = "";
    if (is_double_nat) {
        let trace = capture_cmd("traceroute -n -m 2 -q 1 -w 1 8.8.8.8");
        let lines = split(trace, "\n");
        if (length(lines) >= 3) {
            let m2 = match(lines[2], /2\s+([0-9.]+)/);
            if (m2) hop2_ip = m2[1];
        }
    }

    let detected_mtu = probe_optimal_mtu("8.8.8.8");
    if (detected_mtu < 1280) detected_mtu = 1500; // failsafe fallback

    let tcp_mss = detected_mtu - 40;
    let safe_tun_mtu = detected_mtu - 80;
    if (safe_tun_mtu < 1280) safe_tun_mtu = 1280;
    if (safe_tun_mtu > 1420) safe_tun_mtu = 1420;

    return {
        double_nat: is_double_nat,
        wan_ip: wan.ip,
        gateway: wan.gw,
        hop2_ip: hop2_ip,
        interface: wan.ifname,
        link_mtu: detected_mtu,
        tcp_mss: tcp_mss,
        safe_tun_mtu: safe_tun_mtu,
        safe_awg_mtu: safe_tun_mtu
    };
}

function apply_tcp_mss_clamp(tcp_mss) {
    if (tcp_mss < 1200 || tcp_mss > 1500)
        tcp_mss = 1460;

    // Check if ForkopTable exists
    if (!run_cmd("nft list table inet " + NFT_TABLE_NAME))
        return false;

    // Remove existing MSS clamp rule if present
    run_cmd("nft delete rule inet " + NFT_TABLE_NAME + " mangle_forward handle $(nft -a list chain inet " + NFT_TABLE_NAME + " mangle_forward | grep 'FlowGate TCP MSS Clamp' | awk '{print $NF}') 2>/dev/null");

    // Add TCP MSS clamp rule to mangle_forward chain
    let rule = "nft add rule inet " + NFT_TABLE_NAME + " mangle_forward tcp flags syn tcp option maxseg size set " + tcp_mss + " counter comment \"FlowGate TCP MSS Clamp\"";
    return run_cmd(rule);
}

function fix() {
    let res = detect();

    // 1. Save settings to UCI without restarting physical network interfaces
    if (uci.available()) {
        uci.set(CONFIG_NAME + ".settings.optimal_link_mtu", "" + res.link_mtu);
        uci.set(CONFIG_NAME + ".settings.tcp_mss", "" + res.tcp_mss);
        uci.set(CONFIG_NAME + ".settings.awg_mtu", "" + res.safe_awg_mtu);
        uci.set(CONFIG_NAME + ".settings.tun_mtu", "" + res.safe_tun_mtu);
        uci.set(CONFIG_NAME + ".settings.double_nat_detected", res.double_nat ? "1" : "0");
        uci.commit(CONFIG_NAME);
    }

    // 2. Apply TCP MSS clamp on the fly in NFTables (zero downtime)
    let clamped = apply_tcp_mss_clamp(res.tcp_mss);
    res.applied_mss_clamping = clamped;
    res.success = true;

    return res;
}

function module_exports() {
    return {
        detect,
        fix,
        apply_tcp_mss_clamp,
        probe_optimal_mtu
    };
}

if ((sourcepath(1) != null && sourcepath(1) != "") || ARGV[0] == null)
    return module_exports();

let mode = ARGV[0] || "";
if (mode == "detect") {
    print(sprintf("%J", detect()), "\n");
    exit(0);
}
else if (mode == "fix") {
    print(sprintf("%J", fix()), "\n");
    exit(0);
}
else {
    warn("Usage: network/mtu.uc <detect|fix>\n");
    exit(1);
}

