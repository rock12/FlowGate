#!/bin/sh
# shellcheck shell=dash
# ==============================================================================
# FlowGate / Forkop Uninstaller & Cleanup Script
# Полное чистое удаление FlowGate с сохранением резервной копии конфигурации.
# ==============================================================================

set -u

UNINSTALLER_VERSION="1.1.4"

# ─── TUI helpers & Color detection ───────────────────────────────────────────
ESC="$(printf '\033')"
_tui_colors=0
if [ -t 1 ] 2>/dev/null; then
    case "${TERM:-dumb}" in
        dumb) _tui_colors=0 ;;
        *)    _tui_colors=1 ;;
    esac
fi

if [ "$_tui_colors" -eq 1 ]; then
    _c_reset="${ESC}[0m"
    _c_bold="${ESC}[1m"
    _c_dim="${ESC}[2m"
    _c_red="${ESC}[31;1m"
    _c_green="${ESC}[32;1m"
    _c_yellow="${ESC}[33;1m"
    _c_blue="${ESC}[34;1m"
    _c_cyan="${ESC}[36;1m"
    _c_magenta="${ESC}[35;1m"
else
    _c_reset=''
    _c_bold=''
    _c_dim=''
    _c_red=''
    _c_green=''
    _c_yellow=''
    _c_blue=''
    _c_cyan=''
    _c_magenta=''
fi

_tui_width() {
    if [ -t 1 ] 2>/dev/null && command -v stty >/dev/null 2>&1; then
        _w="$(stty size 2>/dev/null | awk '{print $2}')"
        [ -n "$_w" ] && [ "$_w" -gt 0 ] 2>/dev/null && printf '%s' "$_w" && return 0
    fi
    printf '70'
}

_tui_hline() {
    _w="$(_tui_width)"
    _char="${1:--}"
    _i=0
    while [ "$_i" -lt "$_w" ]; do
        printf '%s' "$_char"
        _i=$((_i + 1))
    done
}

tui_banner() {
    printf '\n'
    printf '  %s%s⚡ FlowGate / Forkop Clean Uninstaller%s v%s\n' "$_c_cyan" "$_c_bold" "$_c_reset" "$UNINSTALLER_VERSION"
    printf '  %sПолное удаление пакетов, сетевых правил и восстановление сети/DNS%s\n' "$_c_dim" "$_c_reset"
    printf '  %s%s%s\n\n' "$_c_dim" "$(_tui_hline '─')" "$_c_reset"
}

tui_step() {
    _step_no="$1"
    _step_total="$2"
    _step_text="$3"
    printf '  %s%s[ %s/%s ]%s %s%s%s\n' \
        "$_c_blue" "$_c_bold" \
        "$_step_no" "$_step_total" \
        "$_c_reset" \
        "$_c_bold" "$_step_text" "$_c_reset"
}

tui_ok() {
    printf '  %s%s✓%s %s\n' "$_c_green" "$_c_bold" "$_c_reset" "$1"
}

tui_warn() {
    printf '  %s%s⚠%s %s\n' "$_c_yellow" "$_c_bold" "$_c_reset" "$1"
}

tui_info() {
    printf '  %s%sℹ%s %s\n' "$_c_cyan" "$_c_dim" "$_c_reset" "$1"
}

# ─── Options parsing ─────────────────────────────────────────────────────────
OPT_PURGE=0
OPT_YES=0
OPT_KEEP_BINARIES=0

for _arg in "$@"; do
    case "$_arg" in
        --purge|-p)
            OPT_PURGE=1
            ;;
        --yes|-y)
            OPT_YES=1
            ;;
        --keep-binaries)
            OPT_KEEP_BINARIES=1
            ;;
        --help|-h)
            printf 'Использование: %s [ОПЦИИ]\n' "$0"
            printf 'Опции:\n'
            printf '  -y, --yes            Выполнить удаление без подтверждения\n'
            printf '  -p, --purge          Полное удаление вместе с резервными копиями конфига\n'
            printf '      --keep-binaries  Не удалять бинарники sing-box / udpspeeder\n'
            printf '  -h, --help           Показать эту справку\n\n'
            exit 0
            ;;
        *)
            ;;
    esac
done

# ─── Root check ──────────────────────────────────────────────────────────────
if [ "$(id -u 2>/dev/null || echo 1)" -ne 0 ]; then
    printf '%sОшибка: скрипт удаления должен запускаться с правами root!%s\n' "$_c_red" "$_c_reset" >&2
    exit 1
fi

tui_banner

# ─── Confirmation prompt ─────────────────────────────────────────────────────
if [ "$OPT_YES" -eq 0 ] && [ -t 0 ] 2>/dev/null; then
    printf '  Вы действительно хотите удалить %sFlowGate / Forkop%s с этого роутера?\n' "$_c_bold" "$_c_reset"
    if [ "$OPT_PURGE" -eq 1 ]; then
        printf '  %sВнимание: указан флаг --purge. Все конфигурации и бэкапы будут удалены!%s\n' "$_c_red" "$_c_reset"
    else
        printf '  Рабочая конфигурация будет сохранена в резервную копию.\n'
    fi
    printf '  Продолжить? [y/N]: '
    read -r _answer
    case "$_answer" in
        y|Y|yes|Yes|YES|да|Да|ДА)
            ;;
        *)
            printf '\n  %sУдаление отменено пользователем.%s\n\n' "$_c_yellow" "$_c_reset"
            exit 0
            ;;
    esac
    printf '\n'
fi

run_with_timeout() {
    _secs="$1"
    shift
    ( "$@" ) >/dev/null 2>&1 &
    _subpid=$!
    _cnt=0
    while [ "$_cnt" -lt "$_secs" ]; do
        if ! kill -0 "$_subpid" 2>/dev/null; then
            wait "$_subpid" 2>/dev/null || true
            return 0
        fi
        sleep 1
        _cnt=$((_cnt + 1))
    done
    for _child in $(pgrep -P "$_subpid" 2>/dev/null || true); do
        kill -9 "$_child" 2>/dev/null || true
    done
    kill -9 "$_subpid" 2>/dev/null || true
    wait "$_subpid" 2>/dev/null || true
    return 1
}

TOTAL_STEPS=6
CURRENT_STEP=1

# ─── STEP 1: Backup Configuration ────────────────────────────────────────────
tui_step "$CURRENT_STEP" "$TOTAL_STEPS" "Создание резервной копии конфигурации..."
BACKUP_PATH=""
if [ "$OPT_PURGE" -eq 0 ]; then
    TIMESTAMP="$(date +%Y%m%d_%H%M%S 2>/dev/null || date +%s)"
    if [ -f "/etc/config/forkop" ]; then
        BACKUP_PATH="/etc/config/forkop.backup-${TIMESTAMP}"
        cp -af "/etc/config/forkop" "$BACKUP_PATH" 2>/dev/null || true
        cp -af "/etc/config/forkop" "/etc/config/forkop.bak" 2>/dev/null || true
        chmod 600 "$BACKUP_PATH" "/etc/config/forkop.bak" 2>/dev/null || true
        tui_ok "Конфигурация успешно сохранена в: ${BACKUP_PATH}"
    else
        tui_info "Конфигурационный файл /etc/config/forkop не найден, бэкап пропущен."
    fi
else
    tui_warn "Режим --purge: резервное копирование конфигурации отключено."
fi

CURRENT_STEP=$((CURRENT_STEP + 1))

# ─── STEP 2: Stop Services & Daemons ─────────────────────────────────────────
tui_step "$CURRENT_STEP" "$TOTAL_STEPS" "Остановка служб и фоновых процессов..."

# 1. Immediately clean up procd lock files to release any stuck flocks
rm -f /tmp/lock/procd_forkop* /tmp/lock/*sing-box* 2>/dev/null || true
rm -rf /var/run/forkop*.lock /tmp/forkop*.lock /var/run/forkop/ui-state/*.lock /var/run/forkop/*.lock 2>/dev/null || true
rm -f /var/run/forkop/start*.pid /var/run/forkop/start.retry 2>/dev/null || true

# 2. Immediately remove autostart symlinks directly (never hang on rc.common flock)
rm -f /etc/rc.d/*forkop* /etc/rc.d/*sing-box* 2>/dev/null || true
if [ -f "/etc/init.d/sing-box" ] && grep -q "Forkop managed sing-box" "/etc/init.d/sing-box" 2>/dev/null; then
    rm -f "/etc/init.d/sing-box" 2>/dev/null || true
fi

# 3. Tell procd to stop tracking/respawning services immediately
if command -v ubus >/dev/null 2>&1; then
    ubus call service delete '{"name": "forkop"}' >/dev/null 2>&1 || true
    ubus call service delete '{"name": "sing-box"}' >/dev/null 2>&1 || true
fi

# 4. Forcefully kill all proxy, DPI, speeder and worker processes
killall -9 sing-box 2>/dev/null || true
killall -9 udpspeeder speederv2 nfqws nfqws2 ciadpi 2>/dev/null || true

# Terminate any running processes executing forkop or flock
for _pdir in /proc/[0-9]*; do
    [ -d "$_pdir" ] || continue
    _p="${_pdir##*/}"
    [ "$_p" = "$$" ] && continue
    if [ -r "$_pdir/cmdline" ]; then
        if tr '\0' ' ' < "$_pdir/cmdline" 2>/dev/null | grep -E -q "forkop|procd_forkop"; then
            kill -9 "$_p" 2>/dev/null || true
        fi
    fi
done

# Clean any PID files that were tracked in runtime dirs
for _pidfile in /var/run/forkop/*.pid /tmp/forkop/*.pid; do
    if [ -f "$_pidfile" ]; then
        _p="$(head -n 1 "$_pidfile" 2>/dev/null || true)"
        [ -n "$_p" ] && [ "$_p" != "$$" ] && kill -9 "$_p" 2>/dev/null || true
        rm -f "$_pidfile" 2>/dev/null || true
    fi
done

tui_ok "Службы и фоновые процессы завершены"

CURRENT_STEP=$((CURRENT_STEP + 1))

# ─── STEP 3: Clean up Network, nftables & Policy Routing ─────────────────────
tui_step "$CURRENT_STEP" "$TOTAL_STEPS" "Очистка сетевых таблиц nftables и политик маршрутизации..."

if command -v nft >/dev/null 2>&1; then
    nft delete table inet ForkopTable >/dev/null 2>&1 || true
    nft delete table inet forkop >/dev/null 2>&1 || true
    nft delete table ip forkop >/dev/null 2>&1 || true
    nft delete table ip6 forkop >/dev/null 2>&1 || true
    rm -f /usr/share/nftables.d/chain-pre/input/*forkop*.nft 2>/dev/null || true
    rm -f /usr/share/nftables.d/rules/*forkop*.nft 2>/dev/null || true
    if [ -x "/etc/init.d/firewall" ]; then
        run_with_timeout 8 /etc/init.d/firewall restart || true
    fi
    tui_ok "Таблицы nftables удалены, фаервол сброшен"
fi

if command -v ip >/dev/null 2>&1; then
    ip -4 rule del fwmark 0x04000000/0x04000000 table forkop priority 105 >/dev/null 2>&1 || true
    ip -6 rule del fwmark 0x04000000/0x04000000 table forkop priority 105 >/dev/null 2>&1 || true
    ip -4 rule del fwmark 0x10000000/0x10000000 lookup 100 >/dev/null 2>&1 || true
    ip -4 rule del lookup forkop >/dev/null 2>&1 || true
    ip route flush table forkop >/dev/null 2>&1 || true
    ip route flush table 105 >/dev/null 2>&1 || true

    if [ -f "/etc/iproute2/rt_tables" ]; then
        sed -i '/105[[:space:]]\+forkop/d' /etc/iproute2/rt_tables 2>/dev/null || true
    fi

    tui_ok "Политики маршрутизации (table forkop/105) сброшены"
fi

CURRENT_STEP=$((CURRENT_STEP + 1))

# ─── STEP 4: Restore DNS & dnsmasq ───────────────────────────────────────────
tui_step "$CURRENT_STEP" "$TOTAL_STEPS" "Восстановление конфигурации DNS и dnsmasq..."

rm -f /etc/dnsmasq.d/forkop*.conf 2>/dev/null || true
rm -f /tmp/dnsmasq.d/forkop*.conf 2>/dev/null || true
rm -rf /tmp/forkop 2>/dev/null || true

if command -v uci >/dev/null 2>&1 && [ -f "/etc/config/dhcp" ]; then
    uci -q del_list dhcp.@dnsmasq[0].server="127.0.0.42" 2>/dev/null || true

    _orig_servers="$(uci -q get dhcp.@dnsmasq[0].forkop_server 2>/dev/null || true)"
    if [ -n "$_orig_servers" ]; then
        uci -q delete dhcp.@dnsmasq[0].server 2>/dev/null || true
        for _srv in $_orig_servers; do
            [ "$_srv" != "127.0.0.42" ] && uci -q add_list dhcp.@dnsmasq[0].server="$_srv" 2>/dev/null || true
        done
        uci -q delete dhcp.@dnsmasq[0].forkop_server 2>/dev/null || true
    fi

    for _opt in noresolv cachesize rebind_protection localuse addn_hosts notinterface; do
        _val="$(uci -q get "dhcp.@dnsmasq[0].forkop_${_opt}" 2>/dev/null || true)"
        if [ -n "$_val" ]; then
            uci -q set "dhcp.@dnsmasq[0].${_opt}=${_val}" 2>/dev/null || true
            uci -q delete "dhcp.@dnsmasq[0].forkop_${_opt}" 2>/dev/null || true
        fi
    done

    if [ "$(uci -q get dhcp.@dnsmasq[0].noresolv 2>/dev/null)" = "1" ]; then
        uci -q set dhcp.@dnsmasq[0].noresolv="0" 2>/dev/null || true
    fi
    if [ "$(uci -q get dhcp.@dnsmasq[0].cachesize 2>/dev/null)" = "0" ]; then
        uci -q set dhcp.@dnsmasq[0].cachesize="150" 2>/dev/null || true
    fi

    uci -q delete dhcp.forkop 2>/dev/null || true
    uci -q commit dhcp 2>/dev/null || true
    tui_ok "Параметры DHCP и DNS dnsmasq возвращены в исходное состояние"
fi

if [ -f "/etc/init.d/dnsmasq" ]; then
    run_with_timeout 8 /etc/init.d/dnsmasq restart || true
    tui_ok "Служба dnsmasq перезапущена в штатном режиме"
fi

CURRENT_STEP=$((CURRENT_STEP + 1))

# ─── STEP 5: Clean Crontabs & Remove Packages ────────────────────────────────
tui_step "$CURRENT_STEP" "$TOTAL_STEPS" "Очистка crontab и удаление установленных пакетов..."

if command -v crontab >/dev/null 2>&1; then
    _crontmp="$(mktemp /tmp/cron.XXXXXX 2>/dev/null || echo '/tmp/cron.forkop.tmp')"
    crontab -l 2>/dev/null | grep -v -E 'forkop' > "$_crontmp" || true
    crontab "$_crontmp" 2>/dev/null || true
    rm -f "$_crontmp" 2>/dev/null || true
    tui_ok "Задачи планировщика crontab очищены"
fi

if command -v apk >/dev/null 2>&1 && [ -d "/lib/apk/db" ]; then
    for _pkg in luci-i18n-forkop-ru luci-app-forkop forkop; do
        if [ -f /etc/apk/world ]; then
            sed -i -E "/^${_pkg}([><= ].*)?$/d" /etc/apk/world 2>/dev/null || true
        fi
        if apk info -e "$_pkg" >/dev/null 2>&1; then
            apk del "$_pkg" >/dev/null 2>&1 || true
        fi
    done
    if [ "$OPT_KEEP_BINARIES" -eq 0 ]; then
        for _pkg in sing-box-extended sing-box-tiny; do
            if [ -f /etc/apk/world ]; then
                sed -i -E "/^${_pkg}([><= ].*)?$/d" /etc/apk/world 2>/dev/null || true
            fi
            if apk info -e "$_pkg" >/dev/null 2>&1; then
                apk del "$_pkg" >/dev/null 2>&1 || true
            fi
        done
    fi
    tui_ok "Пакеты удалены через apk-tools"
elif command -v opkg >/dev/null 2>&1; then
    _wait=0
    while [ -f /var/lock/opkg.lock ] || [ -f /var/run/opkg.lock ]; do
        _wait=$((_wait + 1))
        [ "$_wait" -ge 10 ] && break
        sleep 1
    done
    for _pkg in luci-i18n-forkop-ru luci-app-forkop forkop; do
        if opkg list-installed "$_pkg" 2>/dev/null | grep -q "^$_pkg "; then
            opkg remove --force-depends --force-remove "$_pkg" >/dev/null 2>&1 || true
        fi
    done
    if [ "$OPT_KEEP_BINARIES" -eq 0 ]; then
        for _pkg in sing-box-extended sing-box-tiny; do
            if opkg list-installed "$_pkg" 2>/dev/null | grep -q "^$_pkg "; then
                opkg remove --force-depends --force-remove "$_pkg" >/dev/null 2>&1 || true
            fi
        done
    fi
    tui_ok "Пакеты удалены через opkg"
fi

CURRENT_STEP=$((CURRENT_STEP + 1))

# ─── STEP 6: Remove Leftover Files & LuCI Cache ──────────────────────────────
tui_step "$CURRENT_STEP" "$TOTAL_STEPS" "Очистка оставшихся файлов, хуков и кэша LuCI..."

rm -rf /usr/lib/forkop 2>/dev/null || true
rm -rf /usr/share/forkop 2>/dev/null || true
rm -rf /www/luci-static/resources/view/forkop 2>/dev/null || true
rm -f /usr/share/luci/menu.d/luci-app-forkop.json 2>/dev/null || true
rm -f /usr/share/rpcd/acl.d/luci-app-forkop.json 2>/dev/null || true
rm -f /etc/uci-defaults/*forkop* 2>/dev/null || true
rm -f /usr/bin/forkop 2>/dev/null || true
rm -f /etc/init.d/forkop 2>/dev/null || true

if [ "$OPT_KEEP_BINARIES" -eq 0 ]; then
    rm -f /usr/bin/udpspeeder /usr/bin/speederv2 2>/dev/null || true
    if [ ! -f "/lib/apk/db/installed" ] && command -v opkg >/dev/null 2>&1; then
        if ! opkg list-installed "sing-box*" 2>/dev/null | grep -q "^sing-box"; then
            rm -f /usr/bin/sing-box 2>/dev/null || true
        fi
    fi
fi

# Clean translations
rm -f /usr/lib/lua/luci/i18n/forkop.* 2>/dev/null || true
find /usr/lib/lua/luci/i18n/ -name "forkop.*" -delete 2>/dev/null || true

# Clear runtime and temporary state
rm -rf /var/run/forkop* /var/log/forkop* /tmp/forkop* 2>/dev/null || true

# Clear LuCI index and module caches
rm -f /var/luci-indexcache* /tmp/luci-indexcache* /tmp/luci-modulecache/* 2>/dev/null || true

# Clean ucitrack entry
if [ -f "/etc/config/ucitrack" ]; then
    uci -q delete ucitrack.@forkop[0] 2>/dev/null || true
    uci -q commit ucitrack 2>/dev/null || true
fi

# Purge configs and persistent state if requested
if [ "$OPT_PURGE" -eq 1 ]; then
    rm -f /etc/config/forkop* 2>/dev/null || true
    rm -rf /etc/forkop /etc/.forkop /etc/backup/forkop_config 2>/dev/null || true
    tui_ok "Все конфигурации и скрытые состояния FlowGate удалены (--purge)"
fi

# Restart rpcd and uhttpd to immediately update LuCI menu
if [ -f "/etc/init.d/rpcd" ]; then
    run_with_timeout 5 /etc/init.d/rpcd reload || run_with_timeout 5 /etc/init.d/rpcd restart || true
fi
if [ -f "/etc/init.d/uhttpd" ]; then
    run_with_timeout 5 /etc/init.d/uhttpd restart || true
fi

tui_ok "Кэш LuCI очищен, файлы и остаточные фрагменты полностью удалены"

# ─── Final Summary ───────────────────────────────────────────────────────────
printf '\n'
printf '  %s%s%s\n' "$_c_dim" "$(_tui_hline '─')" "$_c_reset"
printf '  %s%s✓ FlowGate / Forkop успешно и чисто удален с вашего роутера!%s\n' "$_c_green" "$_c_bold" "$_c_reset"

if [ "$OPT_PURGE" -eq 0 ] && [ -n "$BACKUP_PATH" ]; then
    printf '  %s📁 Резервная копия конфигурации сохранена:%s %s%s%s\n' "$_c_cyan" "$_c_reset" "$_c_bold" "$BACKUP_PATH" "$_c_reset"
    printf '  %s   (а также продублирована в /etc/config/forkop.bak)%s\n' "$_c_dim" "$_c_reset"
fi

printf '  %s🌐 Сетевой стек и DNS возвращены в штатный режим OpenWrt.%s\n\n' "$_c_dim" "$_c_reset"

exit 0
