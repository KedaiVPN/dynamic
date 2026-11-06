#!/usr/bin/env bash
set -euo pipefail

# Official HTTP Custom SlowDNS package manager.
# The bundled package is the ePro release compatible with HC 8.0.10.914.
SLOWDNS_DIR=${SLOWDNS_DIR:-/root/slowdns}
SLOWDNS_LEGACY_DIR=${SLOWDNS_LEGACY_DIR:-/etc/slowdns}
SLOWDNS_ENV_FILE=${SLOWDNS_ENV_FILE:-$SLOWDNS_DIR/slowdns.env}
SLOWDNS_BIN=${SLOWDNS_BIN:-$SLOWDNS_DIR/slowdns}
SLOWDNS_KEY=${SLOWDNS_KEY:-$SLOWDNS_DIR/server.key}
SLOWDNS_PUB=${SLOWDNS_PUB:-$SLOWDNS_DIR/server.pub}
SLOWDNS_SERVICE=${SLOWDNS_SERVICE:-/etc/systemd/system/slowdns.service}
SLOWDNS_BINARY_URL=${SLOWDNS_BINARY_URL:-https://raw.githubusercontent.com/KedaiVPN/dynamic/main/slowdns-linux-amd64}
SLOWDNS_BINARY_SHA256=${SLOWDNS_BINARY_SHA256:-a9d19e39ae23261628e8f21dac79548b31dceb45f959017bc50300e7ebfcad7d}
SLOWDNS_RESOLVER=${SLOWDNS_RESOLVER:-1.1.1.1:53}
SLOWDNS_UPSTREAM=${SLOWDNS_UPSTREAM:-127.0.0.1:22}

red() { printf '\033[1;91m%s\033[0m\n' "$*"; }
green() { printf '\033[1;92m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;93m%s\033[0m\n' "$*"; }

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        red 'SlowDNS harus dijalankan sebagai root.'
        exit 1
    fi
}

valid_domain() {
    [[ "$1" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ && "$1" == *.* ]]
}

read_domains() {
    local domain=${SLOWDNS_DOMAIN_OVERRIDE:-}
    if [[ -z "$domain" && -r /etc/xray/domain ]]; then
        domain=$(tr -d '[:space:]' < /etc/xray/domain)
    fi
    if ! valid_domain "$domain"; then
        red 'Domain VPS di /etc/xray/domain tidak valid atau belum tersedia.'
        return 1
    fi
    SLOWDNS_DOMAIN=$domain
    SLOWDNS_NS_DOMAIN=${SLOWDNS_NS_DOMAIN_OVERRIDE:-ns-${domain}}
    valid_domain "$SLOWDNS_NS_DOMAIN" || { red 'NS domain SlowDNS tidak valid.'; return 1; }
}

discover_bind_ip() {
    if [[ -n "${SLOWDNS_BIND_IP:-}" ]]; then
        printf '%s' "$SLOWDNS_BIND_IP"
        return 0
    fi
    ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}'
}

install_binary() {
    local tmp actual
    install -d -m 0700 "$SLOWDNS_DIR"
    tmp=$(mktemp "$SLOWDNS_DIR/slowdns.XXXXXX")
    if ! wget -q -O "$tmp" "$SLOWDNS_BINARY_URL" || [[ ! -s "$tmp" ]]; then
        rm -f "$tmp"
        red 'Binary SlowDNS resmi HTTP Custom gagal diunduh.'
        return 1
    fi
    actual=$(sha256sum "$tmp" | awk '{print $1}')
    if [[ "$actual" != "$SLOWDNS_BINARY_SHA256" ]]; then
        rm -f "$tmp"
        red 'Checksum binary SlowDNS resmi tidak cocok; instalasi dibatalkan.'
        return 1
    fi
    install -m 0755 "$tmp" "$SLOWDNS_BIN"
    rm -f "$tmp"
}

migrate_keys() {
    local old_dir=$SLOWDNS_LEGACY_DIR
    install -d -m 0700 "$SLOWDNS_DIR"
    if [[ ! -s "$SLOWDNS_KEY" && -s "$old_dir/server.key" ]]; then
        install -m 0600 "$old_dir/server.key" "$SLOWDNS_KEY"
    fi
    if [[ ! -s "$SLOWDNS_PUB" && -s "$old_dir/server.pub" ]]; then
        install -m 0644 "$old_dir/server.pub" "$SLOWDNS_PUB"
    fi
    if [[ ! -s "$SLOWDNS_KEY" || ! -s "$SLOWDNS_PUB" ]]; then
        "$SLOWDNS_BIN" -gen-key -privkey-file "$SLOWDNS_KEY" -pubkey-file "$SLOWDNS_PUB" >/dev/null
        chmod 600 "$SLOWDNS_KEY"
        chmod 644 "$SLOWDNS_PUB"
    fi
    [[ "$(wc -c < "$SLOWDNS_KEY")" -eq 65 && "$(wc -c < "$SLOWDNS_PUB")" -eq 65 ]] || {
        red 'Format key SlowDNS tidak valid.'
        return 1
    }
}

iptables_rule() { iptables -w 5 "$@"; }

remove_rule_all() {
    local table=$1 chain=$2; shift 2
    while iptables_rule -t "$table" -C "$chain" "$@" >/dev/null 2>&1; do
        iptables_rule -t "$table" -D "$chain" "$@"
    done
}

network_interface() {
    ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="dev") {print $(i+1); exit}}'
}

normalize_udp_custom_nat() {
    local iface=${1:-$(network_interface)}
    [[ -n "$iface" ]] || return 0
    # Older installs redirected every UDP port to UDP Custom. Keep that service,
    # but reserve UDP/53 for the official SlowDNS listener.
    if iptables_rule -t nat -C PREROUTING -i "$iface" -p udp --dport 1:65535 -j DNAT --to-destination :36712 >/dev/null 2>&1; then
        remove_rule_all nat PREROUTING -i "$iface" -p udp --dport 1:65535 -j DNAT --to-destination :36712
        iptables_rule -t nat -I PREROUTING 1 -i "$iface" -p udp --dport 1:52 -j DNAT --to-destination :36712
        iptables_rule -t nat -I PREROUTING 2 -i "$iface" -p udp --dport 54:65535 -j DNAT --to-destination :36712
    fi
}

remove_legacy_slowdns_rules() {
    remove_rule_all nat PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
    remove_rule_all filter INPUT -p udp --dport 5300 -j ACCEPT
    normalize_udp_custom_nat
}

install_network_rules() {
    local ipaddr=$1 iface=$2
    command -v iptables >/dev/null 2>&1 || { red 'iptables tidak tersedia.'; return 1; }
    remove_legacy_slowdns_rules
    iptables_rule -C INPUT -p udp --dport 53 -m comment --comment slowdns-official -j ACCEPT 2>/dev/null || \
        iptables_rule -I INPUT -p udp --dport 53 -m comment --comment slowdns-official -j ACCEPT
    iptables_rule -t raw -C PREROUTING -i "$iface" -d "$ipaddr" -p udp --dport 53 -m comment --comment slowdns-direct -j CT --notrack 2>/dev/null || \
        iptables_rule -t raw -I PREROUTING -i "$iface" -d "$ipaddr" -p udp --dport 53 -m comment --comment slowdns-direct -j CT --notrack
    iptables_rule -t raw -C OUTPUT -s "$ipaddr" -p udp --sport 53 -m comment --comment slowdns-direct -j CT --notrack 2>/dev/null || \
        iptables_rule -t raw -I OUTPUT -s "$ipaddr" -p udp --sport 53 -m comment --comment slowdns-direct -j CT --notrack
    if command -v iptables-save >/dev/null 2>&1 && [[ -d /etc/iptables ]]; then
        iptables-save > /etc/iptables/rules.v4
        chmod 600 /etc/iptables/rules.v4
    fi
}

remove_network_rules() {
    local ipaddr=$1 iface=$2
    command -v iptables >/dev/null 2>&1 || return 0
    remove_rule_all filter INPUT -p udp --dport 53 -m comment --comment slowdns-official -j ACCEPT
    remove_rule_all raw PREROUTING -i "$iface" -d "$ipaddr" -p udp --dport 53 -m comment --comment slowdns-direct -j CT --notrack
    remove_rule_all raw OUTPUT -s "$ipaddr" -p udp --sport 53 -m comment --comment slowdns-direct -j CT --notrack
    if command -v iptables-save >/dev/null 2>&1 && [[ -d /etc/iptables ]]; then iptables-save > /etc/iptables/rules.v4; fi
}

write_env() {
    local ipaddr=$1 iface=$2 tmp
    tmp=$(mktemp "$SLOWDNS_DIR/slowdns.env.XXXXXX")
    printf 'SLOWDNS_ENABLED="1"\nSLOWDNS_BINARY="slowdns"\nSLOWDNS_UDP_ADDR="%s:53"\nSLOWDNS_PRIVKEY_FILE="%s"\nSLOWDNS_DOMAIN="%s"\nSLOWDNS_NS_DOMAIN="%s"\nSLOWDNS_UPSTREAM_ADDR="%s"\nSLOWDNS_RESOLVER="%s"\nSLOWDNS_DIRECT_IPV4="%s"\nSLOWDNS_DIRECT_INTERFACE="%s"\nSLOWDNS_BINARY_SHA256="%s"\n' \
        "$ipaddr" "$SLOWDNS_KEY" "$SLOWDNS_DOMAIN" "$SLOWDNS_NS_DOMAIN" "$SLOWDNS_UPSTREAM" "$SLOWDNS_RESOLVER" "$ipaddr" "$iface" "$SLOWDNS_BINARY_SHA256" > "$tmp"
    chmod 600 "$tmp"
    mv -f "$tmp" "$SLOWDNS_ENV_FILE"
}

write_service() {
    local ipaddr=$1
    cat > "$SLOWDNS_SERVICE" <<EOF
[Unit]
Description=SlowDNS server (HTTP Custom official package)
After=network-online.target ssh.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$SLOWDNS_DIR
EnvironmentFile=$SLOWDNS_ENV_FILE
ExecStart=$SLOWDNS_BIN -udp $ipaddr:53 -privkey-file $SLOWDNS_KEY $SLOWDNS_NS_DOMAIN $SLOWDNS_UPSTREAM
Restart=on-failure
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "$SLOWDNS_SERVICE"
    systemctl daemon-reload
}

status() {
    clear && printf '\033[3J'
    local BIRed='\033[1;91m' BIYellow='\033[1;93m' BIWhite='\033[1;97m' BIGreen='\033[1;92m' UWhite='\033[4;37m' NC='\033[0m'
    echo -e "${BIRed} ╔═════════════════════════════════════════════════════╗${NC}"
    echo -e "${BIRed} ║                  ${BIWhite}${UWhite}> SLOWDNS INFO <${NC}                   ${BIRed}║${NC}"
    echo -e "${BIRed} ╠═════════════════════════════════════════════════════╣${NC}"
    if [[ -r "$SLOWDNS_ENV_FILE" ]]; then
        # Read only the fields written by this manager; never source server state.
        local domain ns pub='' stat='' listener='' stat_str=''
        domain=$(awk -F= '$1=="SLOWDNS_DOMAIN" {gsub(/"/,"",$2); print $2}' "$SLOWDNS_ENV_FILE")
        ns=$(awk -F= '$1=="SLOWDNS_NS_DOMAIN" {gsub(/"/,"",$2); print $2}' "$SLOWDNS_ENV_FILE")
        listener=$(awk -F= '$1=="SLOWDNS_UDP_ADDR" {gsub(/"/,"",$2); print $2}' "$SLOWDNS_ENV_FILE")
        [[ -r "$SLOWDNS_PUB" ]] && pub=$(tr -d '[:space:]' < "$SLOWDNS_PUB")
        stat=$(systemctl is-active slowdns.service 2>/dev/null || true)
        if [[ "$stat" == "active" ]]; then
            stat_str="${BIGreen}active (running)${NC}"
        else
            stat_str="${BIRed}${stat:-nonaktif}${NC}"
        fi
        echo -e "${BIRed} ║ ${BIWhite}Status    : ${stat_str}"
        echo -e "${BIRed} ║ ${BIWhite}Domain    : ${BIYellow}${domain}${NC}"
        echo -e "${BIRed} ║ ${BIWhite}Ns-Domain : ${BIYellow}${ns}${NC}"
        echo -e "${BIRed} ║ ${BIWhite}Listener  : ${BIWhite}${listener}${NC}"
        echo -e "${BIRed} ║ ${BIWhite}Pubkey    : ${BIWhite}${pub}${NC}"
    else
        echo -e "${BIRed} ║ ${BIWhite}Status    : ${BIRed}nonaktif${NC}"
    fi
    echo -e "${BIRed} ╚═════════════════════════════════════════════════════╝${NC}"
    echo ""
}

enable_slowdns() {
    require_root
    read_domains || return 1
    command -v systemctl >/dev/null 2>&1 || { red 'systemd tidak tersedia.'; return 1; }
    local ipaddr iface
    ipaddr=$(discover_bind_ip)
    iface=$(network_interface)
    [[ "$ipaddr" =~ ^[0-9]+(\.[0-9]+){3}$ && -n "$iface" ]] || { red 'Tidak dapat menentukan IP/interface IPv4 VPS.'; return 1; }
    install_binary || return 1
    migrate_keys || return 1
    write_env "$ipaddr" "$iface"
    write_service "$ipaddr"
    install_network_rules "$ipaddr" "$iface" || return 1
    systemctl enable slowdns.service >/dev/null
    systemctl restart slowdns.service
    if ! systemctl is-active --quiet slowdns.service || ! ss -lunH 2>/dev/null | awk '{print $4}' | grep -Fq "$ipaddr:53"; then
        red 'SlowDNS gagal aktif. Periksa: journalctl -u slowdns.service -n 50'
        return 1
    fi
    green 'SlowDNS resmi HTTP Custom aktif.'
    echo "Domain    : $SLOWDNS_DOMAIN"
    echo "Ns-Domain : $SLOWDNS_NS_DOMAIN"
    echo "Pubkey    : $(cat "$SLOWDNS_PUB")"
}

disable_slowdns() {
    require_root
    systemctl disable --now slowdns.service >/dev/null 2>&1 || true
    local ipaddr iface
    ipaddr=$(awk -F= '$1=="SLOWDNS_DIRECT_IPV4" {gsub(/"/,"",$2); print $2}' "$SLOWDNS_ENV_FILE" 2>/dev/null || true)
    iface=$(awk -F= '$1=="SLOWDNS_DIRECT_INTERFACE" {gsub(/"/,"",$2); print $2}' "$SLOWDNS_ENV_FILE" 2>/dev/null || true)
    [[ -n "$ipaddr" && -n "$iface" ]] && remove_network_rules "$ipaddr" "$iface"
    [[ -f "$SLOWDNS_ENV_FILE" ]] && sed -i 's/^SLOWDNS_ENABLED=.*/SLOWDNS_ENABLED="0"/' "$SLOWDNS_ENV_FILE"
    green 'SlowDNS nonaktif. Key dan konfigurasi resmi dipertahankan.'
}

menu() {
    local BIRed='\033[1;91m' BIYellow='\033[1;93m' BIWhite='\033[1;97m' UWhite='\033[4;37m' NC='\033[0m'
    while true; do
        clear && printf '\033[3J'
        echo -e "${BIRed} ╔═════════════════════════════════════════════════════╗${NC}"
        echo -e "${BIRed} ║                  ${BIWhite}${UWhite}> SLOWDNS MENU <${NC}                   ${BIRed}║${NC}"
        echo -e "${BIRed} ╠═════════════════════════════════════════════════════╣${NC}"
        echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 1${BIRed}]${BIWhite} Aktifkan SlowDNS                             ${BIRed}║${NC}"
        echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 2${BIRed}]${BIWhite} Nonaktifkan SlowDNS                          ${BIRed}║${NC}"
        echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 3${BIRed}]${BIWhite} Cek Status SlowDNS                           ${BIRed}║${NC}"
        echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 4${BIRed}]${BIWhite} Informasi SlowDNS                            ${BIRed}║${NC}"
        echo -e "${BIRed} ║   ${BIRed}[${BIWhite} x${BIRed}]${BIWhite} Kembali ke Menu SSH                          ${BIRed}║${NC}"
        echo -e "${BIRed} ╚═════════════════════════════════════════════════════╝${NC}"
        echo -e "     ${BIYellow}Press x or [ Ctrl+C ] • To-${BIWhite}Exit${NC}"
        echo ""
        read -p " Select menu : " option
        echo -e ""
        case "$option" in
            1|01) enable_slowdns; read -n 1 -s -r -p "Press any key to back on menu" ;;
            2|02) disable_slowdns; read -n 1 -s -r -p "Press any key to back on menu" ;;
            3|03|4|04) status; read -n 1 -s -r -p "Press any key to back on menu" ;;
            x|X) return 0 ;;
            *) echo "Press any key to back on menu"; sleep 1 ;;
        esac
    done
}

case "${1:-menu}" in
enable|on) enable_slowdns ;;
disable|off) disable_slowdns ;;
status|info) status ;;
menu) menu ;;
*) echo "Usage: $0 {enable|disable|status|menu}" >&2; exit 2 ;;
esac
