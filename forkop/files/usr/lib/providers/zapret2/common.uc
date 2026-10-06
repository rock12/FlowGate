#!/usr/bin/env ucode

let fs = require("fs");
let constants = require("core.constants");
let validator_module = null;

const LIB_DIR = getenv("FORKOP_LIB") || "/usr/lib/forkop";

function validator() {
    if (validator_module == null)
        validator_module = require("providers.zapret2.validator");
    return validator_module;
}

function resolve_lua_init(dir, name) {
    if (fs.stat(dir + "/" + name) != null)
        return "@" + dir + "/" + name;
    if (fs.stat(dir + "/" + name + ".gz") != null)
        return "@" + dir + "/" + name + ".gz";
    return "@" + dir + "/" + name;
}

function resolve_zapret2_bin(runtime_constants) {
    let candidate_bins = [
        getenv("ZAPRET2_NFQWS2_BIN"),
        getenv("ZAPRET2_PROVIDER_NFQWS2_BIN"),
        runtime_constants.ZAPRET2_PROVIDER_NFQWS2_BIN,
        "/opt/zapret2/nfq2/nfqws2",
        "/opt/zapret2/nfq/nfqws2",
        "/opt/zapret2/nfqws2",
        "/usr/bin/nfqws2"
    ];
    for (let b in candidate_bins) {
        if (b && fs.stat(b) != null)
            return b;
    }
    return runtime_constants.ZAPRET2_PROVIDER_NFQWS2_BIN;
}

function resolve_zapret2_lua_dir(runtime_constants) {
    let candidate_dirs = [
        getenv("ZAPRET2_PROVIDER_LUA_DIR"),
        runtime_constants.ZAPRET2_PROVIDER_LUA_DIR,
        "/opt/zapret2/lua",
        "/opt/zapret/lua",
        "/usr/share/zapret2/lua",
        "/etc/zapret2/lua"
    ];
    for (let d in candidate_dirs) {
        if (d && fs.stat(d) != null)
            return d;
    }
    return runtime_constants.ZAPRET2_PROVIDER_LUA_DIR;
}

function config(ctx) {
    let runtime_constants = (ctx && ctx.constants) || constants;
    let lib_dir = (ctx && ctx.lib_dir) || LIB_DIR;
    let desync_mark = getenv("ZAPRET2_DESYNC_MARK") || runtime_constants.ZAPRET2_DESYNC_MARK;
    let provider_bin = resolve_zapret2_bin(runtime_constants);
    let provider_lua_dir = resolve_zapret2_lua_dir(runtime_constants);

    return {
        kind: "zapret2",
        action: "zapret2",
        binary_name: "nfqws2",
        binary: provider_bin,
        provider_bin: provider_bin,
        provider_files_dir: getenv("ZAPRET2_PROVIDER_FILES_DIR") || runtime_constants.ZAPRET2_PROVIDER_FILES_DIR,
        provider_ipset_dir: getenv("ZAPRET2_PROVIDER_IPSET_DIR") || runtime_constants.ZAPRET2_PROVIDER_IPSET_DIR,
        provider_lua_dir,
        state_dir: getenv("ZAPRET2_STATE_DIR") || runtime_constants.ZAPRET2_STATE_DIR,
        pid_dir: getenv("ZAPRET2_PID_DIR") || runtime_constants.ZAPRET2_PID_DIR,
        child_pid_dir: getenv("ZAPRET2_CHILD_PID_DIR") || runtime_constants.ZAPRET2_CHILD_PID_DIR,
        log_dir: getenv("ZAPRET2_LOG_DIR") || runtime_constants.ZAPRET2_LOG_DIR,
        route_mark_base: getenv("ZAPRET2_ROUTE_MARK_BASE") || runtime_constants.ZAPRET2_ROUTE_MARK_BASE,
        queue_base: getenv("ZAPRET2_QUEUE_BASE") || runtime_constants.ZAPRET2_QUEUE_BASE,
        queue_range_size: getenv("ZAPRET2_QUEUE_RANGE_SIZE") || runtime_constants.ZAPRET2_QUEUE_RANGE_SIZE,
        respawn_delay: getenv("ZAPRET2_NFQWS2_RESPAWN_DELAY") || runtime_constants.ZAPRET2_NFQWS2_RESPAWN_DELAY,
        desync_mark,
        desync_mark_postnat: getenv("ZAPRET2_DESYNC_MARK_POSTNAT") || runtime_constants.ZAPRET2_DESYNC_MARK_POSTNAT,
        default_strategy: getenv("ZAPRET2_DEFAULT_NFQWS2_OPT") || runtime_constants.ZAPRET2_DEFAULT_NFQWS2_OPT,
        legacy_default_strategy: "",
        strategy_option: "nfqws2_opt",
        validator_kind: "nfqws2",
        validator,
        package_name: "zapret2",
        runtime_path: lib_dir + "/providers/zapret2/runtime.uc",
        check_path: lib_dir + "/providers/zapret2/check.uc",
        luci_package: "luci-app-zapret2",
        luci_menu: "/usr/share/luci/menu.d/luci-app-zapret2.json",
        luci_acl: "/usr/share/rpcd/acl.d/luci-app-zapret2.json",
        service_init: "/etc/init.d/zapret2",
        config_name: "zapret2",
        legacy_runtime_base: "",
        hostlist_dir: "",
        status_label: "zapret2",
        check_prefix: "zapret2",
        base_args: [
            "--fwmark=" + desync_mark,
            "--bind-fix4",
            "--bind-fix6",
            "--lua-init=" + resolve_lua_init(provider_lua_dir, "zapret-lib.lua"),
            "--lua-init=" + resolve_lua_init(provider_lua_dir, "zapret-antidpi.lua"),
            "--lua-init=" + resolve_lua_init(provider_lua_dir, "zapret-auto.lua")
        ]
    };
}

return {
    config,
    validator
};
