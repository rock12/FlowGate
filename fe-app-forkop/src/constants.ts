export const FORKOP_UCI_PACKAGE = 'forkop';
export const FORKOP_LUCI_APP_VERSION = '__COMPILED_VERSION_VARIABLE__';
export const FORKOP_ACTION_PROVIDERS_AVAILABILITY_EVENT =
  'forkop:action-providers-availability';
export const FAKEIP_CHECK_DOMAIN = 'fakeip.podkop.fyi';
export const IP_CHECK_DOMAIN = 'ip.podkop.fyi';
export const DEFAULT_LATENCY_TEST_URL = 'https://www.gstatic.com/generate_204';
export const LATENCY_TEST_URL_OPTIONS = [
  DEFAULT_LATENCY_TEST_URL,
  'https://cp.cloudflare.com/generate_204',
  'https://captive.apple.com',
  'https://connectivity-check.ubuntu.com',
];

export const DOMAIN_LIST_OPTIONS = {
  russia_inside: 'Russia inside',
  russia_outside: 'Russia outside',
  ukraine_inside: 'Ukraine',
  geoblock: 'Geo Block',
  block: 'Block',
  porn: 'Porn',
  news: 'News',
  anime: 'Anime',
  youtube: 'Youtube',
  discord: 'Discord',
  meta: 'Meta',
  twitter: 'Twitter (X)',
  hdrezka: 'HDRezka',
  tiktok: 'Tik-Tok',
  telegram: 'Telegram',
  cloudflare: 'Cloudflare',
  google_ai: 'Google AI',
  google_play: 'Google Play',
  hodca: 'H.O.D.C.A',
  roblox: 'Roblox',
  ads_hagezi_pro: 'Ads (Hagezi Pro)',
  supercell: 'Supercell',
  github: 'GitHub',
  hetzner: 'Hetzner ASN',
  ovh: 'OVH ASN',
  digitalocean: 'Digital Ocean ASN',
  cloudfront: 'CloudFront ASN',
  wz_wardogs: 'War Dogs (Game)',
  wz_apex: 'Apex Legends (Game)',
  wz_fortnite: 'Fortnite (Game)',
  wz_darksouls: 'Dark Souls / Elden Ring (Game)',
  wz_ru_gaming_all: 'RU Gaming Blocklist (All)',
  wz_activision: 'Activision Blizzard (Game)',
  wz_servers: 'Warzone Match Servers (Game)',
  wz_ea: 'Electronic Arts (EA)',
  wz_xbox: 'Xbox Live',
  wz_steam: 'Steam Community & Games',
  wz_download: 'Downloads (Direct WAN)',
  wz_torrent: 'Torrent Trackers',
  wz_win_spy: 'Windows Telemetry (Block)',
  wz_whitelist: 'Whitelist (Gosuslugi / Banks)',
  wz_gemini: 'Google Gemini',
  wz_copilot: 'Microsoft Copilot',
  wz_adobe: 'Adobe',
  wz_netflix: 'Netflix',
};

export const DNS_SERVER_OPTIONS = {
  '1.1.1.1': '1.1.1.1 (Cloudflare)',
  '8.8.8.8': '8.8.8.8 (Google)',
  '9.9.9.9': '9.9.9.9 (Quad9)',
  'dns.adguard-dns.com': 'dns.adguard-dns.com (AdGuard Default)',
  'unfiltered.adguard-dns.com':
    'unfiltered.adguard-dns.com (AdGuard Unfiltered)',
  'family.adguard-dns.com': 'family.adguard-dns.com (AdGuard Family)',
};

export const DNS_SERVERS_BY_PROTOCOL: Record<string, Record<string, string>> = {
  udp: {
    '1.1.1.1': '1.1.1.1 (Cloudflare)',
    '1.0.0.1': '1.0.0.1 (Cloudflare Secondary)',
    '8.8.8.8': '8.8.8.8 (Google)',
    '8.8.4.4': '8.8.4.4 (Google Secondary)',
    '9.9.9.9': '9.9.9.9 (Quad9 Filtered)',
    '149.112.112.112': '149.112.112.112 (Quad9 Secondary)',
    '94.140.14.14': '94.140.14.14 (AdGuard Default)',
    '94.140.15.15': '94.140.15.15 (AdGuard Default Secondary)',
    '76.76.2.0': '76.76.2.0 (Control D)',
    '194.242.2.2': '194.242.2.2 (Mullvad)',
    '185.222.222.222': '185.222.222.222 (DNS.SB)',
    '193.110.81.0': '193.110.81.0 (DNS0.EU)',
    '208.67.222.222': '208.67.222.222 (OpenDNS)',
    '223.5.5.5': '223.5.5.5 (AliDNS)',
    '77.88.8.8': '77.88.8.8 (Yandex)',
    '77.88.8.1': '77.88.8.1 (Yandex Secondary)',
  },
  doh: {
    'https://cloudflare-dns.com/dns-query': 'Cloudflare',
    'https://dns.google/dns-query': 'Google',
    'https://dns.quad9.net/dns-query': 'Quad9 (Filtered)',
    'https://dns.adguard-dns.com/dns-query': 'AdGuard Default',
    'https://dns.mullvad.net/dns-query': 'Mullvad Base',
    'https://dns.nextdns.io/dns-query': 'NextDNS',
    'https://freedns.controld.com/p0': 'Control D Uncensored',
    'https://doh.dns.sb/dns-query': 'DNS.SB',
    'https://zero.dns0.eu': 'DNS0.EU Zero',
    'https://odvr.nic.cz/doh': 'CZ.NIC ODVR',
    'https://dns.alidns.com/dns-query': 'AliDNS',
    'https://doh.opendns.com/dns-query': 'OpenDNS',
    'https://common.dot.dns.yandex.net/dns-query': 'Yandex',
  },
  dot: {
    '1.1.1.1': '1.1.1.1 (Cloudflare)',
    '1.0.0.1': '1.0.0.1 (Cloudflare Secondary)',
    'dns.google': 'Google',
    'dns.quad9.net': 'Quad9 (Filtered)',
    'dns.adguard-dns.com': 'AdGuard Default',
    'dns.mullvad.net': 'Mullvad Base',
    'dns.nextdns.io': 'NextDNS',
    'p0.freedns.controld.com': 'Control D Uncensored',
    'dot.sb': 'DNS.SB',
    'zero.dns0.eu': 'DNS0.EU Zero',
    'dns.alidns.com': 'AliDNS',
    'common.dot.dns.yandex.net': 'Yandex',
  },
  doq: {
    '1.1.1.1:784': '1.1.1.1:784 (Cloudflare)',
    '1.0.0.1:784': '1.0.0.1:784 (Cloudflare Secondary)',
    'dns.google:784': 'Google',
    'dns.adguard-dns.com:785': 'AdGuard Default',
    'p0.freedns.controld.com:853': 'Control D',
    'dns.mullvad.net:784': 'Mullvad',
    'dns.nextdns.io:784': 'NextDNS',
    'zero.dns0.eu:853': 'DNS0.EU Zero',
  },
};

export const BOOTSTRAP_DNS_SERVER_OPTIONS = {
  '77.88.8.8': '77.88.8.8 (Yandex DNS)',
  '77.88.8.1': '77.88.8.1 (Yandex DNS)',
  '1.1.1.1': '1.1.1.1 (Cloudflare DNS)',
  '1.0.0.1': '1.0.0.1 (Cloudflare DNS)',
  '8.8.8.8': '8.8.8.8 (Google DNS)',
  '8.8.4.4': '8.8.4.4 (Google DNS)',
  '9.9.9.9': '9.9.9.9 (Quad9 DNS)',
  '9.9.9.11': '9.9.9.11 (Quad9 DNS)',
};

export const COMMAND_TIMEOUT = 10000; // 10 seconds
