#!/bin/sh
# shellcheck shell=dash
# Forkop - Dependency installer for OpenWrt (supports both opkg and apk)

set -e

msg() {
    printf '\033[32;1m%s\033[0m\n' "$1"
}

warn() {
    printf '\033[33;1m%s\033[0m\n' "$1"
}

fail() {
    printf '\033[31;1m%s\033[0m\n' "$1" >&2
    exit 1
}

[ "$(id -u 2>/dev/null)" = "0" ] || fail "Пожалуйста, запустите скрипт от пользователя root"
[ -f /etc/openwrt_release ] || fail "Этот скрипт предназначен только для OpenWrt"

PKG_IS_APK=0
command -v apk >/dev/null 2>&1 && PKG_IS_APK=1

msg "==> Обновление списков пакетов..."
if [ "$PKG_IS_APK" -eq 1 ]; then
    apk update </dev/null
else
    opkg update </dev/null
fi

pkg_is_installed() {
    pkg="$1"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk info -e "$pkg" >/dev/null 2>&1
    else
        opkg list-installed 2>/dev/null | awk -v p="$pkg" '$1 == p { found = 1 } END { exit(found ? 0 : 1) }'
    fi
}

install_pkg() {
    pkg="$1"
    if pkg_is_installed "$pkg"; then
        return 0
    fi
    msg "Установка: $pkg"
    if [ "$PKG_IS_APK" -eq 1 ]; then
        apk add "$pkg" </dev/null || warn "Пакет $pkg не найден в репозитории или встроен в ядро"
    else
        opkg install "$pkg" </dev/null || warn "Пакет $pkg не найден в репозитории или встроен в ядро"
    fi
}

msg "==> Установка основных зависимостей и библиотек ucode..."
for pkg in ucode ucode-mod-fs ucode-mod-uci curl ca-bundle bind-dig ip-full coreutils-base64 nftables traceroute iputils-ping; do
    install_pkg "$pkg"
done

msg "==> Установка необходимых модулей ядра Linux..."
for mod in kmod-tun kmod-nft-tproxy kmod-nft-nat kmod-inet-diag kmod-netlink-diag; do
    install_pkg "$mod"
done

msg "==> Проверка и установка модулей AmneziaWG (для WARP и кастомных AWG туннелей)..."
for awg in kmod-amneziawg amneziawg-tools; do
    install_pkg "$awg"
done

msg "==> Отключение аппаратного и программного Flow Offloading (конфликт с TPROXY)..."
if command -v uci >/dev/null 2>&1; then
    uci set firewall.@defaults[0].flow_offloading='0' 2>/dev/null || true
    uci set firewall.@defaults[0].flow_offloading_hw='0' 2>/dev/null || true
    uci commit firewall 2>/dev/null || true
    /etc/init.d/firewall reload >/dev/null 2>&1 || true
fi

msg "==> Отключение IPv6 (предотвращение утечек через провайдера)..."
sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true
sysctl -w net.ipv6.conf.lo.disable_ipv6=0 >/dev/null 2>&1 || true
if [ -d /etc/sysctl.d ]; then
    cat << 'EOF' > /etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 0
EOF
fi
if command -v uci >/dev/null 2>&1; then
    uci set dhcp.lan.dhcpv6='disabled' 2>/dev/null || true
    uci set dhcp.lan.ra='disabled' 2>/dev/null || true
    uci commit dhcp 2>/dev/null || true
    /etc/init.d/odhcpd reload >/dev/null 2>&1 || true
fi

msg "==> Проверка наличия UDPspeeder..."
if ! command -v udpspeeder >/dev/null 2>&1 && ! command -v speederv2 >/dev/null 2>&1; then
    msg "Загрузка бинарного файла UDPspeeder (speederv2)..."
    ARCH="$(uname -m 2>/dev/null || true)"
    BIN_NAME=""
    case "$ARCH" in
        aarch64*|arm64*) BIN_NAME="speederv2_arm" ;;
        armv7*|armv6*|arm*) BIN_NAME="speederv2_arm" ;;
        x86_64*|amd64*) BIN_NAME="speederv2_amd64" ;;
        mips*le*) BIN_NAME="speederv2_mips24kc_le" ;;
        mips*) BIN_NAME="speederv2_mips24kc_be" ;;
        *) BIN_NAME="speederv2_arm" ;;
    esac

    TMP_SPEEDER="$(mktemp -d /tmp/udpspeeder.XXXXXX 2>/dev/null || echo /tmp)"
    SPEEDER_URL="https://github.com/wangyu-/UDPspeeder/releases/download/20230206.0/speederv2_binaries.tar.gz"
    if curl -sSL -k "$SPEEDER_URL" -o "$TMP_SPEEDER/speederv2.tar.gz" 2>/dev/null; then
        tar -xzf "$TMP_SPEEDER/speederv2.tar.gz" -C "$TMP_SPEEDER" 2>/dev/null || true
        if [ -f "$TMP_SPEEDER/$BIN_NAME" ]; then
            cp "$TMP_SPEEDER/$BIN_NAME" /usr/bin/udpspeeder
            chmod 755 /usr/bin/udpspeeder
            ln -sf /usr/bin/udpspeeder /usr/bin/speederv2 2>/dev/null || true
            msg "UDPspeeder успешно установлен в /usr/bin/udpspeeder"
        fi
    fi
    rm -rf "$TMP_SPEEDER" 2>/dev/null || true
fi

msg "==> Все зависимости успешно проверены и установлены!"
