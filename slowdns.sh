#!/usr/bin/env bash
set -euo pipefail

SLOWDNS_DIR=/etc/slowdns
SLOWDNS_CONFIG="$SLOWDNS_DIR/config"
SLOWDNS_KEY="$SLOWDNS_DIR/server.key"
SLOWDNS_PUB="$SLOWDNS_DIR/server.pub"
SLOWDNS_BIN="$SLOWDNS_DIR/dnstt-server"
SLOWDNS_SERVICE=/etc/systemd/system/slowdns.service
SLOWDNS_INTERNAL_PORT=5300
SLOWDNS_REPO=https://dnstt.network
SLOWDNS_CHECKSUM_URL="$SLOWDNS_REPO/SHA256SUMS"

red() { printf '\033[1;91m%s\033[0m\n' "$*"; }
green() { printf '\033[1;92m%s\033[0m\n' "$*"; }
yellow() { printf '\033[1;93m%s\033[0m\n' "$*"; }

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        red 'SlowDNS harus dijalankan sebagai root.'
        exit 1
    fi
}

read_domain() {
    local domain=''
    [[ -r /etc/xray/domain ]] && domain=$(tr -d '[:space:]' < /etc/xray/domain)
    if [[ ! "$domain" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$ || "$domain" != *.* ]]; then
        red 'Domain VPS di /etc/xray/domain tidak valid atau belum tersedia.'
        return 1
    fi
    SLOWDNS_DOMAIN="$domain"
    SLOWDNS_NS_DOMAIN="ns-${domain}"
}

arch_asset() {
    case "$(uname -m)" in
        x86_64|amd64) printf '%s' 'dnstt-server-linux-amd64' ;;
        aarch64|arm64) printf '%s' 'dnstt-server-linux-arm64' ;;
        *) red "Arsitektur $(uname -m) belum didukung oleh installer SlowDNS."; return 1 ;;
    esac
}

install_binary() {
    local asset expected actual tmp
    asset=$(arch_asset) || return 1
    mkdir -p "$SLOWDNS_DIR"
    tmp=$(mktemp "$SLOWDNS_DIR/dnstt-server.XXXXXX")
    if ! wget -q -O "$tmp" "$SLOWDNS_REPO/$asset"; then
        rm -f "$tmp"
        red 'Gagal mengunduh binary DNSTT.'
        return 1
    fi
    expected=$(wget -qO- "$SLOWDNS_CHECKSUM_URL" | awk -v f="$asset" '$2==f {print $1}')
    actual=$(sha256sum "$tmp" | awk '{print $1}')
    if [[ -z "$expected" || "$actual" != "$expected" ]]; then
        rm -f "$tmp"
        red 'Checksum binary DNSTT tidak cocok; instalasi dibatalkan.'
        return 1
    fi
    chmod 755 "$tmp"
    mv -f "$tmp" "$SLOWDNS_BIN"
}

generate_keypair() {
    if [[ -s "$SLOWDNS_KEY" && -s "$SLOWDNS_PUB" ]]; then
        return 0
    fi
    "$SLOWDNS_BIN" -gen-key -privkey-file "$SLOWDNS_KEY" -pubkey-file "$SLOWDNS_PUB" >/dev/null
    chmod 600 "$SLOWDNS_KEY"
    chmod 644 "$SLOWDNS_PUB"
}

write_config() {
    local tmp
    tmp=$(mktemp "$SLOWDNS_DIR/config.XXXXXX")
    printf 'enabled=1\ndomain=%s\nns_domain=%s\ninternal_port=%s\n' \
        "$SLOWDNS_DOMAIN" "$SLOWDNS_NS_DOMAIN" "$SLOWDNS_INTERNAL_PORT" > "$tmp"
    chmod 600 "$tmp"
    mv -f "$tmp" "$SLOWDNS_CONFIG"
}

persist_firewall_rules() {
    if command -v iptables-save >/dev/null 2>&1 && [[ -d /etc/iptables ]]; then
        iptables-save > /etc/iptables/rules.v4
        chmod 600 /etc/iptables/rules.v4
    fi
}

install_firewall_rule() {
    command -v iptables >/dev/null 2>&1 || { red 'iptables tidak tersedia.'; return 1; }
    iptables -C INPUT -p udp --dport "$SLOWDNS_INTERNAL_PORT" -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p udp --dport "$SLOWDNS_INTERNAL_PORT" -j ACCEPT
    iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports "$SLOWDNS_INTERNAL_PORT" 2>/dev/null || \
        iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports "$SLOWDNS_INTERNAL_PORT"
    persist_firewall_rules
}

remove_firewall_rule() {
    command -v iptables >/dev/null 2>&1 || return 0
    while iptables -t nat -C PREROUTING -p udp --dport 53 -j REDIRECT --to-ports "$SLOWDNS_INTERNAL_PORT" 2>/dev/null; do
        iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-ports "$SLOWDNS_INTERNAL_PORT"
    done
    while iptables -C INPUT -p udp --dport "$SLOWDNS_INTERNAL_PORT" -j ACCEPT 2>/dev/null; do
        iptables -D INPUT -p udp --dport "$SLOWDNS_INTERNAL_PORT" -j ACCEPT
    done
    persist_firewall_rules
}

write_service() {
    cat > "$SLOWDNS_SERVICE" <<EOF
[Unit]
Description=Kedai SSH SlowDNS (DNSTT)
After=network-online.target ssh.service
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$SLOWDNS_DIR
ExecStart=$SLOWDNS_BIN -udp :$SLOWDNS_INTERNAL_PORT -privkey-file $SLOWDNS_KEY $SLOWDNS_NS_DOMAIN 127.0.0.1:22
Restart=on-failure
RestartSec=3
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
ReadWritePaths=$SLOWDNS_DIR

[Install]
WantedBy=multi-user.target
EOF
    chmod 644 "$SLOWDNS_SERVICE"
    systemctl daemon-reload
}

status() {
    if [[ -r "$SLOWDNS_CONFIG" ]]; then
        domain=$(awk -F= '$1=="domain" {print $2}' "$SLOWDNS_CONFIG")
        ns_domain=$(awk -F= '$1=="ns_domain" {print $2}' "$SLOWDNS_CONFIG")
        echo "Status     : $(systemctl is-active slowdns.service 2>/dev/null || true)"
        echo "Domain     : $domain"
        echo "Ns-Domain  : $ns_domain"
        echo "Pubkey     : $(cat "$SLOWDNS_PUB" 2>/dev/null || true)"
    else
        echo 'Status     : nonaktif'
    fi
}

enable_slowdns() {
    require_root
    read_domain || return 1
    if ! command -v systemctl >/dev/null 2>&1; then red 'systemd tidak tersedia.'; return 1; fi
    if ss -lunH 2>/dev/null | awk '{print $5}' | grep -Eq '(^|:)5300$'; then
        red 'UDP port 5300 sedang digunakan service lain.'
        return 1
    fi
    if ss -lunH 2>/dev/null | awk '{print $5}' | grep -Eq '(^|:)(53)$'; then
        red 'UDP port 53 sedang digunakan service lain; SlowDNS tidak diaktifkan.'
        return 1
    fi
    install_binary || return 1
    generate_keypair || return 1
    write_service
    install_firewall_rule || return 1
    systemctl enable slowdns.service >/dev/null
    systemctl restart slowdns.service
    if ! systemctl is-active --quiet slowdns.service; then
        remove_firewall_rule
        red 'SlowDNS gagal aktif. Periksa: journalctl -u slowdns.service -n 50'
        return 1
    fi
    write_config
    green 'SlowDNS aktif.'
    echo "Domain    : $SLOWDNS_DOMAIN"
    echo "Ns-Domain : $SLOWDNS_NS_DOMAIN"
    echo "Pubkey    : $(cat "$SLOWDNS_PUB")"
}

disable_slowdns() {
    require_root
    systemctl disable --now slowdns.service >/dev/null 2>&1 || true
    remove_firewall_rule
    if [[ -f "$SLOWDNS_CONFIG" ]]; then
        sed -i 's/^enabled=.*/enabled=0/' "$SLOWDNS_CONFIG"
    fi
    green 'SlowDNS nonaktif. Key dan konfigurasi dipertahankan agar akun lama tidak berubah.'
}

menu() {
    while true; do
        clear && printf '\033[3J'
        echo '╔══════════════════════════════════════════════════════════╗'
        echo '║                         SLOWDNS                          ║'
        echo '╠══════════════════════════════════════════════════════════╣'
        echo '[01] AKTIFKAN SLOWDNS'
        echo '[02] NONAKTIFKAN SLOWDNS'
        echo '[03] CEK STATUS SLOWDNS'
        echo '[04] LIHAT INFORMASI SLOWDNS'
        echo '[x ] KEMBALI'
        echo '╚══════════════════════════════════════════════════════════╝'
        read -rp ' Select menu : ' option
        case "$option" in
            1|01) enable_slowdns; read -n 1 -s -r -p 'Tekan tombol untuk kembali...' ;;
            2|02) disable_slowdns; read -n 1 -s -r -p 'Tekan tombol untuk kembali...' ;;
            3|03|4|04) status; read -n 1 -s -r -p 'Tekan tombol untuk kembali...' ;;
            x|X) return 0 ;;
            *) ;;
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
