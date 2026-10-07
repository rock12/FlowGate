"use strict";
"require form";
"require uci";
"require ui";
"require fs";
"require baseclass";
"require tools.widgets as widgets";
"require view.forkop.main as main";

const UCI_PACKAGE = main.FORKOP_UCI_PACKAGE;

function isSingBoxDuration(value) {
  return /^(?=.*[1-9])([0-9]+(?:\.[0-9]+)?(?:ns|us|ms|s|m|h|d))+$/.test(value);
}

function latencyTestUrlChoices() {
  return Array.isArray(main.LATENCY_TEST_URL_OPTIONS)
    ? main.LATENCY_TEST_URL_OPTIONS
    : [main.DEFAULT_LATENCY_TEST_URL || "https://www.gstatic.com/generate_204"];
}

function validateLatencyTestUrl(value) {
  const validation = main.validateUrl(`${value || ""}`.trim());
  return validation.valid ? true : validation.message;
}

function isDownloadSectionAction(action, capabilities) {
  switch (action) {
    case "connection":
    case "proxy":
    case "outbound":
    case "vpn":
      return true;
    case "zapret":
      return !capabilities?.loaded || Boolean(capabilities.zapretInstalled);
    case "zapret2":
      return !capabilities?.loaded || Boolean(capabilities.zapret2Installed);
    case "byedpi":
      return !capabilities?.loaded || Boolean(capabilities.byedpiInstalled);
    default:
      return false;
  }
}

function refreshDownloadSectionChoices(option, capabilities) {
  const sections = option.map?.data?.state?.values?.[UCI_PACKAGE] ?? {};

  option.keylist = [];
  option.vallist = [];

  for (const secName in sections) {
    const sec = sections[secName];
    if (
      sec[".type"] === "section" &&
      sec.enabled !== "0" &&
      isDownloadSectionAction(sec.action, capabilities)
    ) {
      option.value(secName, sec.label || secName);
    }
  }
}

function configureDownloadSectionOption(option, sectionOption, capabilities) {
  option.default = "";
  option.rmempty = false;
  option.cfgvalue = function (section_id) {
    return uci.get(UCI_PACKAGE, section_id, sectionOption) || "";
  };
  option.load = function (section_id) {
    refreshDownloadSectionChoices(this, capabilities);
    return this.cfgvalue(section_id);
  };
  option.write = function (section_id, value) {
    const normalized = value ? `${value}`.trim() : "";

    if (normalized) {
      uci.set(UCI_PACKAGE, section_id, sectionOption, normalized);
    } else {
      uci.unset(UCI_PACKAGE, section_id, sectionOption);
    }
  };
  option.remove = function (section_id) {
    uci.unset(UCI_PACKAGE, section_id, sectionOption);
  };
  option.validate = function (_section_id, value) {
    return value ? true : _("Select a section");
  };
}

function configureDownloadViaProxyFlag(option, sectionOption) {
  option.default = "0";
  option.rmempty = false;
  option.write = function (section_id, value) {
    const enabled = value === "1" || value === true;
    uci.set(UCI_PACKAGE, section_id, this.option, enabled ? "1" : "0");
    if (!enabled) {
      uci.unset(UCI_PACKAGE, section_id, sectionOption);
    }
  };
}

function optionListValues(option, section_id) {
  const formValue = option.formvalue(section_id);
  const value = formValue != null ? formValue : option.cfgvalue(section_id);
  return L.toArray(value)
    .map((item) => `${item || ""}`.trim())
    .filter(Boolean);
}

function configureDnsList(option, choices, defaultValue) {
  Object.entries(choices).forEach(([key, label]) => {
    option.value(key, _(label));
  });
  option.default = [defaultValue];
  option.rmempty = false;
  option.validate = function (_section_id, value) {
    const normalized = `${value || ""}`.trim();
    if (!normalized) {
      return optionListValues(option, _section_id).length > 0
        ? true
        : _("Add at least one DNS server");
    }
    const validation = main.validateDNS(normalized);
    return validation.valid ? true : validation.message;
  };
}

function refreshOptionChoices(option, choices) {
  delete option.keylist;
  delete option.vallist;
  (choices || []).forEach((choice) => {
    if (typeof choice === "object") {
      option.value(choice.value, choice.label);
    } else {
      option.value(choice);
    }
  });
}

function getDnsServerChoices(dnsType) {
  const servers =
    (main.DNS_SERVERS_BY_PROTOCOL && main.DNS_SERVERS_BY_PROTOCOL[dnsType]) ||
    (main.DNS_SERVERS_BY_PROTOCOL && main.DNS_SERVERS_BY_PROTOCOL.udp) ||
    main.DNS_SERVER_OPTIONS;
  return Object.entries(servers).map(([value, label]) => ({
    value,
    label: _(label),
  }));
}

function getDefaultDnsServers(dnsType) {
  const servers =
    (main.DNS_SERVERS_BY_PROTOCOL && main.DNS_SERVERS_BY_PROTOCOL[dnsType]) ||
    (main.DNS_SERVERS_BY_PROTOCOL && main.DNS_SERVERS_BY_PROTOCOL.udp) ||
    main.DNS_SERVER_OPTIONS;
  const keys = Object.keys(servers);
  return keys.length > 0 ? [keys[0]] : ["77.88.8.8"];
}

const settingsDnsDynamicState = {
  dnsType: null,
  widget: null,
  option: null,
  refreshers: new Map(),
  valuesByProtocol: {},
};

function configureDnsDynamicList(option, getChoices, defaultValue) {
  option.default = [defaultValue];
  option.rmempty = false;
  option.validate = function (_section_id, value) {
    const normalized = `${value || ""}`.trim();
    if (!normalized) {
      return optionListValues(option, _section_id).length > 0
        ? true
        : _("Add at least one DNS server");
    }
    const validation = main.validateDNS(normalized);
    return validation.valid ? true : validation.message;
  };
  option.renderWidget = function (section_id, _option_index, cfgvalue) {
    const values = L.toArray(cfgvalue != null ? cfgvalue : this.default);
    const initialType = uci.get(UCI_PACKAGE, section_id, "dns_type") || "udp";
    settingsDnsDynamicState.dnsType = initialType;
    if (values && values.length > 0) {
      settingsDnsDynamicState.valuesByProtocol[initialType] = values.slice();
    }
    const choices = getChoices(section_id, values);
    const labels = {};
    choices.forEach((choice) => {
      labels[choice.value] = choice.label;
    });
    refreshOptionChoices(this, choices);
    let choiceSignature = JSON.stringify(
      choices.map((choice) => [choice.value, choice.label]),
    );
    const widget = new ui.DynamicList(values, labels, {
      id: this.cbid(section_id),
      sort: this.keylist,
      optional: this.optional || this.rmempty,
      datatype: this.datatype,
      placeholder: this.placeholder,
      validate: L.bind(this.validate, this, section_id),
      disabled: this.readonly != null ? this.readonly : this.map.readonly,
    });
    const node = widget.render();
    const refreshChoices = () => {
      if (!node.isConnected) return false;
      const currentValues = widget.getValue();
      const currentChoices = getChoices(section_id, currentValues);
      const currentLabels = {};
      currentChoices.forEach((choice) => {
        currentLabels[choice.value] = choice.label;
      });
      const currentSignature = JSON.stringify(
        currentChoices.map((choice) => [choice.value, choice.label]),
      );
      if (currentSignature === choiceSignature) return;
      choiceSignature = currentSignature;
      refreshOptionChoices(this, currentChoices);
      widget.choices = currentLabels;
      widget.clearChoices();
      widget.addChoices(
        currentChoices.map((choice) => choice.value),
        currentLabels,
      );
    };
    const refreshBeforeOpening = (event) => {
      if (event.target && event.target.closest(".add-item")) refreshChoices();
    };
    node.addEventListener("mousedown", refreshBeforeOpening, true);
    node.addEventListener("focusin", refreshBeforeOpening, true);
    if (!settingsDnsDynamicState.refreshers.has(section_id)) {
      settingsDnsDynamicState.refreshers.set(section_id, new Set());
    }
    settingsDnsDynamicState.refreshers.get(section_id).add(refreshChoices);
    settingsDnsDynamicState.widget = widget;
    settingsDnsDynamicState.option = this;
    return node;
  };
}

function configureDnsFailoverVisibility(option, dnsOption, bootstrapOption, fallbackOption) {
  option.depends("dns_server", "__forkop_multiple_dns__");
  option.depends("bootstrap_dns_server", "__forkop_multiple_dns__");
  option.retain = true;
  option.checkDepends = function (section_id) {
    return (
      optionListValues(dnsOption, section_id).length > 1 ||
      optionListValues(bootstrapOption, section_id).length > 1 ||
      (fallbackOption && optionListValues(fallbackOption, section_id).length > 0)
    );
  };
}

function configureDnsDuration(
  option,
  defaultValue,
  dnsOption,
  bootstrapOption,
  fallbackOption,
) {
  option.default = defaultValue;
  option.rmempty = false;
  option.validate = function (_section_id, value) {
    const normalized = `${value || ""}`.trim();
    if (!normalized || !isSingBoxDuration(normalized)) {
      return _("Use sing-box duration format like 10s, 1m or 2m30s");
    }
    return true;
  };
  configureDnsFailoverVisibility(option, dnsOption, bootstrapOption, fallbackOption);
}

function createSettingsContent(section, capabilities) {
  let o = section.option(
    form.ListValue,
    "dns_type",
    _("DNS Protocol Type"),
    _("Select DNS protocol to use"),
  );
  o.value("doh", _("DNS over HTTPS (DoH)"));
  o.value("dot", _("DNS over TLS (DoT)"));
  o.value("doq", _("DNS over QUIC (DoQ)"));
  o.value("udp", _("UDP (Unprotected DNS)"));
  o.default = "udp";
  o.rmempty = false;

  const dnsTypeOption = o;

  const dnsOption = section.option(
    form.DynamicList,
    "dns_server",
    _("DNS Servers"),
    _(
      "Main DNS server. If multiple servers are selected, a timeout switches to a backup.",
    ),
  );
  configureDnsDynamicList(
    dnsOption,
    (_section_id) => {
      const dnsType =
        settingsDnsDynamicState.dnsType ||
        uci.get(main.FORKOP_UCI_PACKAGE, "settings", "dns_type") ||
        "udp";
      return getDnsServerChoices(dnsType);
    },
    "77.88.8.8",
  );

  const bootstrapOption = section.option(
    form.DynamicList,
    "bootstrap_dns_server",
    _("Bootstrap DNS Servers"),
    _(
      "DNS server used to obtain IP addresses for upstream DNS and proxies. If multiple servers are selected, a timeout switches to a backup.",
    ),
  );
  configureDnsList(
    bootstrapOption,
    main.BOOTSTRAP_DNS_SERVER_OPTIONS,
    "77.88.8.8",
  );

  const fallbackDnsOption = section.option(
    form.DynamicList,
    "dns_fallback_server",
    _("Fallback DNS Servers"),
    _(
      "Plain-UDP DNS servers used as a last resort when all primary DNS fail. These are always unencrypted (no DoH/DoT). Example: 1.1.1.1, 8.8.8.8. Unlike the ISP fallback toggle, these are your own chosen servers.",
    ),
  );
  configureDnsList(fallbackDnsOption, main.BOOTSTRAP_DNS_SERVER_OPTIONS, "");
  fallbackDnsOption.rmempty = true;
  fallbackDnsOption.default = [];
  fallbackDnsOption.validate = function (_section_id, value) {
    const normalized = `${value || ""}`.trim();
    if (!normalized) return true;
    if (normalized.includes("://") || normalized.includes("/"))
      return _(
        "Fallback DNS servers must be plain UDP (IP or hostname). DoH/DoT URLs are not allowed here.",
      );
    const validation = main.validateDNS(normalized);
    return validation.valid ? true : validation.message;
  };

  dnsTypeOption.onchange = function (_ev, section_id, value) {
    const newType = value || "udp";
    const oldType = settingsDnsDynamicState.dnsType || "udp";
    if (newType === oldType) return;

    const widget = settingsDnsDynamicState.widget;
    if (widget) {
      const currentValues = widget.getValue();
      const currentList = Array.isArray(currentValues)
        ? currentValues.map((v) => `${v || ""}`.trim()).filter(Boolean)
        : [];
      if (currentList.length > 0) {
        settingsDnsDynamicState.valuesByProtocol[oldType] = currentList;
      }

      let targetServers = settingsDnsDynamicState.valuesByProtocol[newType];
      if (!targetServers || !targetServers.length) {
        targetServers = getDefaultDnsServers(newType);
      }

      const choices = getDnsServerChoices(newType);
      const defaultLabels = {};
      choices.forEach((c) => {
        defaultLabels[c.value] = c.label;
      });
      targetServers.forEach((srv) => {
        if (!defaultLabels[srv]) {
          defaultLabels[srv] = srv;
        }
      });

      widget.choices = defaultLabels;
      refreshOptionChoices(
        settingsDnsDynamicState.option || dnsOption,
        choices,
      );
      widget.clearChoices();
      widget.addChoices(
        choices.map((c) => c.value),
        defaultLabels,
      );
      widget.setValue(targetServers);
    }
    settingsDnsDynamicState.dnsType = newType;

    const refreshers = settingsDnsDynamicState.refreshers.get(section_id);
    if (refreshers) {
      refreshers.forEach((fn) => fn());
    }
  };

  o = section.option(
    form.Flag,
    "fallback_wan_main",
    _("Enable WAN DNS Fallback for Main DNS"),
    _(
      "⚠️ If all Main DNS fail 3 times, queries will be sent to your ISP's DNS in plaintext. Only use as a last resort to prevent complete internet loss.",
    ),
  );
  o.default = o.disabled;

  o = section.option(
    form.Flag,
    "fallback_wan_bootstrap",
    _("Enable WAN DNS Fallback for Bootstrap DNS"),
    _(
      "⚠️ If all Bootstrap DNS fail 3 times, queries will be sent to your ISP's DNS in plaintext. Only use as a last resort to prevent complete internet loss.",
    ),
  );
  o.default = o.disabled;

  o = section.option(
    form.Value,
    "dns_check_interval",
    _("DNS Check Interval"),
    _("How often to check the active DNS servers."),
  );
  configureDnsDuration(o, "10s", dnsOption, bootstrapOption, fallbackDnsOption);

  o = section.option(
    form.Value,
    "dns_recovery_check_interval",
    _("Higher-priority DNS Check"),
    _("How often to check whether a higher-priority DNS server has recovered."),
  );
  configureDnsDuration(o, "60s", dnsOption, bootstrapOption, fallbackDnsOption);

  o = section.option(
    form.Value,
    "dns_check_timeout",
    _("DNS Unavailability Timeout"),
    _(
      "Maximum time to wait for example.com to resolve during a DNS health check.",
    ),
  );
  configureDnsDuration(o, "2s", dnsOption, bootstrapOption, fallbackDnsOption);

  o = section.option(
    form.Value,
    "dns_rewrite_ttl",
    _("DNS Rewrite TTL"),
    _("Time in seconds for DNS record caching (default: 60)"),
  );
  o.default = "60";
  o.rmempty = false;
  o.validate = function (section_id, value) {
    if (!value) {
      return _("TTL value cannot be empty");
    }

    const ttl = parseInt(value);
    if (isNaN(ttl) || ttl < 0) {
      return _("TTL must be a positive number");
    }

    return true;
  };

  o = section.option(form.ListValue, "dns_strategy", _("DNS Strategy"));
  o.value("prefer_ipv4", _("Prefer IPv4"));
  o.value("ipv4_only", _("IPv4 only"));
  o.value("prefer_ipv6", _("Prefer IPv6"));
  o.value("ipv6_only", _("IPv6 only"));
  o.default = "prefer_ipv4";
  o.rmempty = false;

  o = section.option(
    form.Flag,
    "dns_detour_enabled",
    _("DNS through proxy"),
    _("Route main DNS requests through the selected section."),
  );
  configureDownloadViaProxyFlag(o, "dns_detour_section");

  o = section.option(
    form.ListValue,
    "dns_detour_section",
    _("DNS requests through section"),
  );
  o.depends("dns_detour_enabled", "1");
  configureDownloadSectionOption(o, "dns_detour_section", capabilities);

  o = section.option(
    widgets.DeviceSelect,
    "source_network_interfaces",
    _("Source Network Interface"),
    _("Select the network interface from which the traffic will originate"),
  );
  o.default = "br-lan";
  o.noaliases = true;
  o.nobridges = false;
  o.noinactive = false;
  o.multiple = true;
  o.filter = function (section_id, value) {
    // Block specific interface names from being selectable
    const blocked = ["wan", "phy0-ap0", "phy1-ap0", "pppoe-wan"];
    if (blocked.includes(value)) {
      return false;
    }

    // Try to find the device object by its name
    const device = this.devices.find((dev) => dev.getName() === value);

    // If no device is found, allow the value
    if (!device) {
      return true;
    }

    // Check the type of the device
    const type = device.getType();

    // Consider any Wi-Fi / wireless / wlan device as invalid
    const isWireless =
      type === "wifi" || type === "wireless" || type.includes("wlan");

    // Allow only non-wireless devices
    return !isWireless;
  };

  o = section.option(
    form.Flag,
    "enable_output_network_interface",
    _("Enable Output Network Interface"),
    _("You can select Output Network Interface, by default autodetect"),
  );
  o.default = "0";
  o.rmempty = false;

  o = section.option(
    widgets.DeviceSelect,
    "output_network_interface",
    _("Output Network Interface"),
    _("Select the network interface to which the traffic will originate"),
  );
  o.noaliases = true;
  o.multiple = false;
  o.depends("enable_output_network_interface", "1");
  o.filter = function (section_id, value) {
    // Blocked interface names that should never be selectable
    const blockedInterfaces = ["br-lan"];

    // Reject immediately if the value matches any blocked interface
    if (blockedInterfaces.includes(value)) {
      return false;
    }

    // Reject lan*
    if (value.startsWith("lan")) {
      return false;
    }

    // Reject tun*, wg*, vpn*, awg*, oc*
    if (
      value.startsWith("tun") ||
      value.startsWith("wg") ||
      value.startsWith("vpn") ||
      value.startsWith("awg") ||
      value.startsWith("oc")
    ) {
      return false;
    }

    // Try to find the device object with the given name
    const device = this.devices.find((dev) => dev.getName() === value);

    // If no device is found, allow the value
    if (!device) {
      return true;
    }

    // Get the device type (e.g., "wifi", "ethernet", etc.)
    const type = device.getType();

    // Reject wireless-related devices
    const isWireless =
      type === "wifi" || type === "wireless" || type.includes("wlan");

    return !isWireless;
  };

  o = section.option(
    form.Flag,
    "enable_badwan_interface_monitoring",
    _("Interface Monitoring"),
    _("Interface monitoring for Bad WAN"),
  );
  o.default = "0";
  o.rmempty = false;

  o = section.option(
    widgets.NetworkSelect,
    "badwan_monitored_interfaces",
    _("Monitored Interfaces"),
    _("Select the WAN interfaces to be monitored"),
  );
  o.depends("enable_badwan_interface_monitoring", "1");
  o.multiple = true;
  o.filter = function (section_id, value) {
    // Reject if the value is in the blocked list ['lan', 'loopback']
    if (["lan", "loopback"].includes(value)) {
      return false;
    }

    // Reject if the value starts with '@' (means it's an alias/reference)
    if (value.startsWith("@")) {
      return false;
    }

    // Otherwise allow it
    return true;
  };

  o = section.option(
    form.Value,
    "badwan_reload_delay",
    _("Interface Monitoring Delay"),
    _("Delay in milliseconds before reloading Forkop after interface UP"),
  );
  o.depends("enable_badwan_interface_monitoring", "1");
  o.default = "2000";
  o.rmempty = false;
  o.validate = function (section_id, value) {
    if (!value) {
      return _("Delay value cannot be empty");
    }
    return true;
  };

  o = section.option(
    form.Flag,
    "enable_yacd",
    _("Enable YACD"),
    `<a href="${main.getClashUIUrl()}" target="_blank">${main.getClashUIUrl()}</a>`,
  );
  o.default = "0";
  o.rmempty = false;

  o = section.option(
    form.Flag,
    "enable_yacd_wan_access",
    _("Enable YACD WAN Access"),
    _(
      "Allows access to YACD from the WAN. Make sure to open the appropriate port in your firewall.",
    ),
  );
  o.depends("enable_yacd", "1");
  o.default = "0";
  o.rmempty = false;

  o = section.option(
    form.Value,
    "yacd_secret_key",
    _("YACD Secret Key"),
    _(
      "Secret key for authenticating remote access to YACD when WAN access is enabled.",
    ),
  );
  o.depends("enable_yacd_wan_access", "1");
  o.rmempty = false;

  o = section.option(
    form.Flag,
    "disable_quic",
    _("Disable QUIC"),
    _(
      "Disable the QUIC protocol to improve compatibility or fix issues with video streaming",
    ),
  );
  o.default = "0";
  o.rmempty = false;

  o = section.option(
    form.Flag,
    "list_update_enabled",
    _("Enable list updates"),
    _("Enable automatic updates for remote lists and rule sets"),
  );
  o.default = "1";
  o.rmempty = false;

  o = section.option(
    form.Value,
    "update_interval",
    _("List Update Frequency"),
    _("Use sing-box duration format like 1d, 12h or 30m"),
  );
  o.depends("list_update_enabled", "1");
  o.placeholder = "1d";
  o.default = "1d";
  o.rmempty = false;
  o.cfgvalue = function (section_id) {
    return uci.get(UCI_PACKAGE, section_id, "update_interval") || "1d";
  };
  o.write = function (section_id, value) {
    const normalized = value ? `${value}`.trim() : "";

    if (normalized.length) {
      uci.set(UCI_PACKAGE, section_id, "update_interval", normalized);
    } else {
      uci.set(UCI_PACKAGE, section_id, "update_interval", "1d");
    }
  };
  o.validate = function (_section_id, value) {
    const normalized = value ? `${value}`.trim() : "";

    if (!normalized.length) {
      return _("Use sing-box duration format like 1d, 12h or 30m");
    }

    if (isSingBoxDuration(normalized)) {
      return true;
    }

    return _("Use sing-box duration format like 1d, 12h or 30m");
  };

  o = section.option(
    form.Flag,
    "component_update_check_enabled",
    _("Automatic component update checks"),
    _("Automatically check installed components for new versions"),
  );
  o.default = "0";
  o.rmempty = false;

  o = section.option(
    form.Value,
    "component_update_check_interval",
    _("Component update check interval"),
    _("Use sing-box duration format like 1d, 12h or 30m"),
  );
  o.depends("component_update_check_enabled", "1");
  o.placeholder = "1d";
  o.default = "1d";
  o.rmempty = false;
  o.cfgvalue = function (section_id) {
    return (
      uci.get(UCI_PACKAGE, section_id, "component_update_check_interval") ||
      "1d"
    );
  };
  o.write = function (section_id, value) {
    const normalized = value ? `${value}`.trim() : "";
    uci.set(
      UCI_PACKAGE,
      section_id,
      "component_update_check_interval",
      normalized.length ? normalized : "1d",
    );
  };
  o.validate = function (_section_id, value) {
    const normalized = value ? `${value}`.trim() : "";

    if (normalized.length && isSingBoxDuration(normalized)) {
      return true;
    }

    return _("Use sing-box duration format like 1d, 12h or 30m");
  };

  o = section.option(
    form.Value,
    "latency_test_url",
    _("Latency test URL"),
    _(
      "Default address for checking server availability and latency. URLTest uses its own address.",
    ),
  );
  latencyTestUrlChoices().forEach((value) => o.value(value));
  o.default =
    main.DEFAULT_LATENCY_TEST_URL || "https://www.gstatic.com/generate_204";
  o.rmempty = false;
  o.validate = function (_section_id, value) {
    return validateLatencyTestUrl(value);
  };

  o = section.option(
    form.Flag,
    "download_lists_via_proxy",
    _("Download lists through a section"),
    _("Download remote lists and rule sets via the selected section"),
  );
  configureDownloadViaProxyFlag(o, "download_lists_via_proxy_section");

  o = section.option(
    form.ListValue,
    "download_lists_via_proxy_section",
    _("Download lists through"),
  );
  o.depends("download_lists_via_proxy", "1");
  configureDownloadSectionOption(
    o,
    "download_lists_via_proxy_section",
    capabilities,
  );

  o = section.option(
    form.Flag,
    "download_components_via_proxy",
    _("Download components through a section"),
    _("Download component packages via the selected section"),
  );
  configureDownloadViaProxyFlag(o, "download_components_via_proxy_section");

  o = section.option(
    form.ListValue,
    "download_components_via_proxy_section",
    _("Download components through"),
  );
  o.depends("download_components_via_proxy", "1");
  configureDownloadSectionOption(
    o,
    "download_components_via_proxy_section",
    capabilities,
  );

  o = section.option(
    form.Flag,
    "dont_touch_dhcp",
    _("Dont Touch My DHCP!"),
    _("Forkop will not modify your DHCP configuration"),
  );
  o.default = "0";
  o.rmempty = false;

  o = section.option(
    form.ListValue,
    "config_path",
    _("Config File Path"),
    _(
      "Select path for sing-box config file. Change this ONLY if you know what you are doing",
    ),
  );
  o.value("/etc/sing-box/config.json", "Flash (/etc/sing-box/config.json)");
  o.value("/tmp/sing-box/config.json", "RAM (/tmp/sing-box/config.json)");
  o.default = "/etc/sing-box/config.json";
  o.rmempty = false;

  o = section.option(
    form.Value,
    "cache_path",
    _("Cache File Path"),
    _(
      "Select or enter path for sing-box cache file. Change this ONLY if you know what you are doing",
    ),
  );
  o.value("/tmp/sing-box/cache.db", "RAM (/tmp/sing-box/cache.db)");
  o.value(
    "/usr/share/sing-box/cache.db",
    "Flash (/usr/share/sing-box/cache.db)",
  );
  o.default = "/tmp/sing-box/cache.db";
  o.rmempty = false;
  o.validate = function (section_id, value) {
    if (!value) {
      return _("Cache file path cannot be empty");
    }

    if (!value.startsWith("/")) {
      return _("Path must be absolute (start with /)");
    }

    if (!value.endsWith("cache.db")) {
      return _("Path must end with cache.db");
    }

    const parts = value.split("/").filter(Boolean);
    if (parts.length < 2) {
      return _("Path must contain at least one directory (like /tmp/cache.db)");
    }

    return true;
  };

  o = section.option(
    form.ListValue,
    "log_level",
    _("Log Level"),
    _("Select the log level for sing-box"),
  );
  o.value("trace", "Trace");
  o.value("debug", "Debug");
  o.value("info", "Info");
  o.value("warn", "Warn");
  o.value("error", "Error");
  o.value("fatal", "Fatal");
  o.value("panic", "Panic");
  o.default = "warn";
  o.rmempty = false;

  o = section.option(
    form.Flag,
    "exclude_ntp",
    _("Exclude NTP"),
    _(
      "Exclude NTP protocol traffic from the tunnel to prevent it from being routed through the proxy or VPN",
    ),
  );
  o.default = "0";
  o.rmempty = false;

  o = section.option(
    form.Flag,
    "torrserver_direct",
    _("Direct TorrServer traffic (Direct WAN)"),
    _(
      "Direct local TorrServer traffic directly to WAN bypassing VPN/TPROXY (similar to Tachyon). Requires TorrServer running under cgroup /services/torrserver.",
    ),
  );
  o.default = "0";
  o.rmempty = false;

  o = section.option(
    form.Flag,
    "game_console_optimizer",
    _("Game Console Optimizer (NAT Type 1)"),
    _(
      "Bypasses UDP traffic for selected game consoles (PS5/Xbox) to achieve NAT Type 1 / 2 (Full Cone NAT) for P2P matchmaking, while keeping TCP (PSN/Auth) routed through the proxy.",
    ),
  );
  o.default = "0";
  o.rmempty = false;

  const gameConsoleIpsOpt = section.option(
    form.DynamicList,
    "game_console_ips",
    _("Game Console IPs"),
    _("Select or enter the IP addresses of your game consoles."),
  );
  gameConsoleIpsOpt.depends("game_console_optimizer", "1");
  gameConsoleIpsOpt.datatype = "ipaddr";

  o = section.option(
    form.Flag,
    "smart_detect",
    _("Enable Smart Detect"),
    _(
      "Auto-detects blocked domains from logs and adds them to the first section where they work via proxy.",
    ),
  );
  o.default = "0";
  o.rmempty = false;

  const smartDetectDescriptions = {
    default: _(
      "Default: uses sing-box error logs and HTTPS HEAD probes. Adds the detected hostname after repeated Direct failures confirmed at least 120 seconds apart and a successful shared proxy probe.",
    ),
    plus: _(
      "Plus: also watches stalled LAN HTTP/HTTPS connections and checks full GET responses. Two failed Direct GET probes and a successful shared proxy GET are required. Saves the main domain with its subdomains using the Public Suffix List. DNS resolution and local certificate errors defer detection.",
    ),
  };

  o = section.option(
    form.ListValue,
    "smart_detect_mode",
    _("Smart Detect mode"),
    smartDetectDescriptions.default,
  );
  o.value("default", _("Default (logs)"));
  o.value("plus", _("Plus (stalled web connections)"));
  o.default = "default";
  o.rmempty = false;
  o.depends("smart_detect", "1");
  o.cfgvalue = function (section_id) {
    return uci.get(UCI_PACKAGE, section_id, "smart_detect_mode") === "plus"
      ? "plus"
      : "default";
  };
  const smartDetectRenderWidget = o.renderWidget;
  o.renderWidget = function (section_id, option_index, cfgvalue) {
    this.description =
      smartDetectDescriptions[cfgvalue === "plus" ? "plus" : "default"];
    return smartDetectRenderWidget.call(
      this,
      section_id,
      option_index,
      cfgvalue,
    );
  };
  o.onchange = function (_ev, section_id, value) {
    this.description =
      smartDetectDescriptions[value === "plus" ? "plus" : "default"];
    const field = this.map.findElement("data-field", this.cbid(section_id));
    const description = field && field.querySelector(".cbi-value-description");
    if (description) description.textContent = this.description;
  };

  o = section.option(
    form.Flag,
    "smart_detect_exclude_ru",
    _("Exclude Russian and Banking domains"),
    _(
      "Prevents .ru, .su, .рф domains and major Russian ecosystems (VK, Yandex, Sber, T-Bank, Gosuslugi) from being auto-added to proxy sections.",
    ),
  );
  o.default = "1";
  o.rmempty = false;
  o.depends("smart_detect", "1");

  o = section.option(
    form.DynamicList,
    "smart_detect_exclude_domains",
    _("Additional excluded domains"),
    _(
      "Domains that must never be auto-detected or routed through proxy sections.",
    ),
  );
  o.depends("smart_detect", "1");

  const smartDetectSecOpt = section.option(
    form.ListValue,
    "smart_detect_section",
    _("Target proxy section"),
    _(
      "Select the proxy section where confirmed blocked domains will be automatically added.",
    ),
  );
  smartDetectSecOpt.depends("smart_detect", "1");
  smartDetectSecOpt.load = function (section_id) {
    this.keylist = [];
    this.vallist = [];
    const sections = uci.sections(UCI_PACKAGE);
    for (const sec of sections) {
      if (
        sec[".type"] === "section" &&
        sec.enabled !== "0" &&
        sec.action !== "bypass" &&
        sec.action !== "block" &&
        sec.action !== "dns"
      ) {
        this.value(sec[".name"], sec.label || sec[".name"]);
      }
    }
    return uci.get(UCI_PACKAGE, section_id, "smart_detect_section") || "";
  };

  o = section.option(
    form.Button,
    "_mtu_fix_btn",
    _("MTU & Double NAT Optimization"),
    _(
      "Detect optimal MTU, Double NAT, and apply zero-downtime TCP MSS Clamping to prevent network drops.",
    ),
  );
  o.inputtitle = _("Detect & Fix MTU");
  o.inputstyle = "apply";
  o.onclick = function () {
    ui.showModal(_("MTU & Double NAT Detection"), [
      E("p", { class: "spinning" }, _("Probing WAN MTU and detecting Double NAT...")),
    ]);
    fs.exec("/usr/bin/forkop", ["detect_mtu"])
      .then(function (res) {
        let data = {};
        try {
          data = JSON.parse((res && res.stdout) || "{}");
        } catch (e) {}

        const content = [
          E("div", { class: "cbi-value" }, [
            E("label", { class: "cbi-value-title" }, _("WAN Interface")),
            E("div", { class: "cbi-value-field" }, data.ifname || _("Unknown")),
          ]),
          E("div", { class: "cbi-value" }, [
            E("label", { class: "cbi-value-title" }, _("WAN IP")),
            E("div", { class: "cbi-value-field" }, data.wan_ip || _("Unknown")),
          ]),
          E("div", { class: "cbi-value" }, [
            E("label", { class: "cbi-value-title" }, _("Double NAT Status")),
            E(
              "div",
              { class: "cbi-value-field", style: data.double_nat ? "color:orange;font-weight:bold;" : "color:green;" },
              data.double_nat
                ? _("Detected (Private IP or multi-hop gateway)")
                : _("Not detected (Direct Public IP)"),
            ),
          ]),
          E("div", { class: "cbi-value" }, [
            E("label", { class: "cbi-value-title" }, _("Detected Link MTU")),
            E("div", { class: "cbi-value-field" }, "" + (data.link_mtu || 1500)),
          ]),
          E("div", { class: "cbi-value" }, [
            E("label", { class: "cbi-value-title" }, _("Optimal TCP MSS")),
            E("div", { class: "cbi-value-field" }, "" + (data.tcp_mss || 1460)),
          ]),
          E("div", { class: "cbi-value" }, [
            E("label", { class: "cbi-value-title" }, _("Safe AWG / TUN MTU")),
            E(
              "div",
              { class: "cbi-value-field" },
              `AWG: ${data.safe_awg_mtu || 1360}, TUN: ${data.safe_tun_mtu || 1400}`,
            ),
          ]),
          E("div", { class: "cbi-value" }, [
            E("label", { class: "cbi-value-title" }, _("TCP MSS Clamping")),
            E(
              "div",
              { class: "cbi-value-field" },
              data.nft_mss_clamped
                ? _("Active in NFTables (Zero Downtime)")
                : _("Not active"),
            ),
          ]),
          E("div", { class: "right", style: "margin-top:1.5em;display:flex;gap:0.5em;justify-content:flex-end;" }, [
            E(
              "button",
              {
                class: "btn cbi-button-action",
                click: function () {
                  ui.showModal(_("Applying MTU Fix"), [
                    E("p", { class: "spinning" }, _("Applying TCP MSS Clamping without restarting network...")),
                  ]);
                  fs.exec("/usr/bin/forkop", ["fix_mtu"])
                    .then(function (fixRes) {
                      ui.showModal(_("MTU Fix Applied"), [
                        E("p", {}, _("Safe MTU and TCP MSS Clamping successfully applied with zero downtime.")),
                        E("div", { class: "right", style: "margin-top:1em;" }, [
                          E("button", { class: "btn", click: ui.hideModal }, _("Close")),
                        ]),
                      ]);
                    })
                    .catch(function (err) {
                      ui.addNotification(null, E("p", {}, err.message || err));
                      ui.hideModal();
                    });
                },
              },
              _("Apply TCP MSS Clamp & Safe MTU"),
            ),
            E("button", { class: "btn", click: ui.hideModal }, _("Close")),
          ]),
        ];
        ui.showModal(_("MTU & Double NAT Diagnostics"), content);
      })
      .catch(function (err) {
        ui.addNotification(null, E("p", {}, err.message || err));
        ui.hideModal();
      });
  };
}

const EntryPoint = {
  createSettingsContent,
};

return baseclass.extend(EntryPoint);
