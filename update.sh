#!/bin/bash
# Script Auto Update untuk Fitur Timezone & Auto-Delete Presisi
# Update: Perbaikan ketidaksesuaian expired tahun 3031-3037 saat membuat akun via API
# Perbaikan dilakukan dengan membersihkan karakter Carriage Return (\r) pada parameter durasi,
# serta mengimplementasikan auto-detection format exp (jumlah hari, date string, atau UNIX timestamp).
# Created by Jules

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "[ ${GREEN}INFO${NC} ] Memulai Update..."

# 1. Update Timezone ke Asia/Jakarta
echo -e "[ ${GREEN}INFO${NC} ] Mengatur Timezone ke Asia/Jakarta..."
timedatectl set-timezone Asia/Jakarta
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# 1.5 Update cron job xp_otm
echo -e "[ ${GREEN}INFO${NC} ] Memastikan cron job auto-delete (xp_otm) terpasang..."
cat > /etc/cron.d/xp_otm <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
* * * * * root /usr/bin/xp
END
chmod 644 /etc/cron.d/xp_otm

# Clear only Xray bandwidth-lock history at 07:00. Keep SSH lock history intact.
cat > /etc/cron.d/clear-xray-limit <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 7 * * * root : > /root/log-xray-limit.txt
END
chmod 644 /etc/cron.d/clear-xray-limit

# 2. Download Script Baru
REPO="https://raw.githubusercontent.com/KedaiVPN/dynamic/main"

echo -e "[ ${GREEN}INFO${NC} ] Mendownload script yang termasuk dalam daftar update..."

download_with_retry() {
    local url="$1"
    local dest="$2"
    local max_attempts="${3:-5}"
    local delay="${4:-2}"
    local tmp_file
    local attempt=1

    mkdir -p "$(dirname "$dest")"
    tmp_file=$(mktemp "${dest}.tmp.XXXXXX") || return 1

    while [ "$attempt" -le "$max_attempts" ]; do
        rm -f "$tmp_file"
        if command -v wget >/dev/null 2>&1; then
            if wget -q --timeout=20 --tries=1 -O "$tmp_file" "$url" && [ -s "$tmp_file" ]; then
                mv -f "$tmp_file" "$dest"
                return 0
            fi
        fi
        rm -f "$tmp_file"
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL --connect-timeout 15 --max-time 120 -o "$tmp_file" "$url" && [ -s "$tmp_file" ]; then
                mv -f "$tmp_file" "$dest"
                return 0
            fi
        fi
        rm -f "$tmp_file"
        if [ "$attempt" -lt "$max_attempts" ]; then
            sleep "$delay"
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

apt_with_retry() {
    local max_attempts=3
    local attempt=1
    while [ "$attempt" -le "$max_attempts" ]; do
        if DEBIAN_FRONTEND=noninteractive apt-get \
            -o DPkg::Lock::Timeout=120 \
            -o Acquire::Retries=5 \
            -o Acquire::http::Timeout=30 \
            -o Acquire::https::Timeout=30 \
            "$@"; then
            return 0
        fi
        DEBIAN_FRONTEND=noninteractive dpkg --configure -a >/dev/null 2>&1 || true
        DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 update -y >/dev/null 2>&1 || true
        attempt=$((attempt + 1))
        sleep 2
    done
    return 1
}

# Static update list. Files not listed here are intentionally left untouched.
# Download, validate Bash syntax, then atomically replace the installed file.
update_local_script() {
    local script_name="$1"
    local target_file="$2"
    local kind="${3:-bash}"
    local tmp_file

    tmp_file=$(mktemp "${target_file}.update.XXXXXX")
    if ! download_with_retry "${REPO}/${script_name}?v=$(date +%s)" "$tmp_file" || [ ! -s "$tmp_file" ]; then
        rm -f "$tmp_file"
        echo -e "[ ${RED}SKIP${NC} ] ${script_name}: source unavailable; existing file was kept."
        return 0
    fi
    case "$kind" in
        bash)
            if ! bash -n "$tmp_file"; then
                rm -f "$tmp_file"
                echo -e "[ ${RED}SKIP${NC} ] ${script_name}: Bash validation failed; existing file was kept."
                return 0
            fi
            ;;
        python)
            if ! python3 -m py_compile "$tmp_file"; then
                rm -f "$tmp_file" "${tmp_file}c"
                echo -e "[ ${RED}SKIP${NC} ] ${script_name}: Python validation failed; existing file was kept."
                return 0
            fi
            rm -f "${tmp_file}c"
            ;;
        *)
            rm -f "$tmp_file"
            echo -e "[ ${RED}SKIP${NC} ] ${script_name}: unknown validator; existing file was kept."
            return 0
            ;;
    esac
    chmod 755 "$tmp_file"
    mv "$tmp_file" "$target_file"
    echo -e "[ ${GREEN}OK${NC} ] ${script_name} updated."
}

# Refresh every terminal-side VMESS/VLESS/Trojan creator. Older servers used
# stale hardcoded /vmess,/vless,/trojan-ws values even after custom-path itself
# was installed; these scripts must read /usr/lib/xray-paths.sh too.
update_local_script "add-ws.sh" "/usr/bin/add-ws" || true
update_local_script "add-vless.sh" "/usr/bin/add-vless" || true
update_local_script "add-tr.sh" "/usr/bin/add-tr" || true
update_local_script "menu-vmess.sh" "/usr/bin/menu-vmess" || true
update_local_script "menu-vless.sh" "/usr/bin/menu-vless" || true
update_local_script "menu-trojan.sh" "/usr/bin/menu-trojan" || true
update_local_script "menu-ssh.sh" "/usr/bin/menu-ssh" || true
update_local_script "tendang.sh" "/usr/bin/tendang" || true
update_local_script "xray-limit.sh" "/usr/bin/xray-limit" || true
update_local_script "menu4.sh" "/usr/bin/menu" || true
update_local_script "custom-path.sh" "/usr/bin/custom-path" || true

# Refresh all other account creators, menus, and utilities so branding & URLs are fully synced
update_local_script "add-trgo.sh" "/usr/bin/add-trgo" || true
update_local_script "add-ssws.sh" "/usr/bin/add-ssws" || true
update_local_script "add-socks.sh" "/usr/bin/add-socks" || true
update_local_script "usernew.sh" "/usr/bin/usernew" || true
update_local_script "menu-ss.sh" "/usr/bin/menu-ss" || true
update_local_script "menu-socks.sh" "/usr/bin/menu-socks" || true
update_local_script "menu-trgo.sh" "/usr/bin/menu-trgo" || true
update_local_script "autoreboot.sh" "/usr/bin/autoreboot" || true
update_local_script "restart.sh" "/usr/bin/restart" || true
update_local_script "clearlog.sh" "/usr/bin/clearlog" || true
update_local_script "logcleaner.sh" "/usr/bin/cleaner" || true
update_local_script "running.sh" "/usr/bin/running" || true
update_local_script "cek-trafik.sh" "/usr/bin/cek-trafik" || true
update_local_script "cek-bandwidth.sh" "/usr/bin/cek-bandwidth" || true
update_local_script "cek-expired.sh" "/usr/bin/cek-expired" || true
# ram.sh is Python and limit-speed.sh is Bash; use their correct validators.
update_local_script "ram.sh" "/usr/bin/cek-ram" python || true
update_local_script "limit-speed.sh" "/usr/bin/limit-speed" bash || true
# bckpbot.sh has no source file in this repository; do not request it.
update_local_script "backup.sh" "/usr/bin/backup" || true
update_local_script "restore.sh" "/usr/bin/restore" || true
update_local_script "webmin.sh" "/usr/bin/wbm" || true
update_local_script "xp.sh" "/usr/bin/xp" || true
update_local_script "dns.sh" "/usr/bin/dns" || true
update_local_script "netf.sh" "/usr/bin/netf" || true
update_local_script "bbr.sh" "/usr/bin/bbr" || true
update_local_script "factory-reset.sh" "/usr/local/bin/factory-reset.sh" || true
update_local_script "update.sh" "/usr/bin/update" || true
update_local_script "slowdns.sh" "/usr/bin/slowdns" || true

# Data-only helper scripts are also syntax-validated before installing.
update_library_script() {
    local script_name="$1"
    local target_file="$2"
    local tmp_file

    tmp_file=$(mktemp "${target_file}.update.XXXXXX")
    if download_with_retry "${REPO}/${script_name}?v=$(date +%s)" "$tmp_file" && bash -n "$tmp_file"; then
        chmod 644 "$tmp_file"
        mv "$tmp_file" "$target_file"
        echo -e "[ ${GREEN}OK${NC} ] ${script_name} updated."
    else
        rm -f "$tmp_file"
        echo -e "[ ${RED}ERROR${NC} ] Failed to update ${script_name}; existing file was kept."
        return 1
    fi
}

# Update only the manager and metadata reader. SlowDNS remains opt-in: users
# activate or migrate it explicitly from menu SSH → SLOWDNS.
update_library_script "slowdns-config.sh" "/usr/lib/slowdns-config.sh" || true
update_library_script "xray-paths.sh" "/usr/lib/xray-paths.sh" || true
update_library_script "xray-account-detail.sh" "/usr/lib/xray-account-detail.sh" || true
# # wget -q -O /usr/bin/xray-limit "${REPO}/xray-limit.sh" && chmod +x /usr/bin/xray-limit
# wget -q -O /home/.ver "${REPO}/test/versions"
# # wget -q -O /usr/bin/tendang "${REPO}/tendang.sh" && chmod +x /usr/bin/tendang
# # # # wget -q -O /usr/bin/menu-ssh "${REPO}/menu-ssh.sh" && chmod +x /usr/bin/menu-ssh
# Update UDP Custom for HTTP Custom app
# echo -e "[ ${GREEN}INFO${NC} ] Menerapkan patch UDP Custom..."
# wget -q -O /root/udp-custom.sh "${REPO}/udp-custom.sh"
# if [ -f "/root/udp-custom.sh" ]; then
#     chmod +x /root/udp-custom.sh
#     cd /root
#     ./udp-custom.sh
#     rm -f /root/udp-custom.sh
# else
#     echo -e "[ ${RED}ERROR${NC} ] Gagal mendownload udp-custom.sh"
# fi

# # wget -q -O /usr/bin/menu-vmess "${REPO}/menu-vmess.sh" && chmod +x /usr/bin/menu-vmess
# # wget -q -O /usr/bin/menu-vless "${REPO}/menu-vless.sh" && chmod +x /usr/bin/menu-vless
# # wget -q -O /usr/bin/menu-trojan "${REPO}/menu-trojan.sh" && chmod +x /usr/bin/menu-trojan
# # wget -q -O /usr/bin/menu-ss "${REPO}/menu-ss.sh" && chmod +x /usr/bin/menu-ss
# # wget -q -O /usr/bin/cek-trafik "${REPO}/cek-trafik.sh" && chmod +x /usr/bin/cek-trafik
# Scripts previously updated here are now handled safely with syntax validation by update_local_script above
# # wget -q -O /usr/local/bin/factory-reset.sh "${REPO}/factory-reset.sh" && chmod +x /usr/local/bin/factory-reset.sh

echo -e "[ ${GREEN}INFO${NC} ] Mengupdate rclone.conf..."
mkdir -p /root/.config/rclone
# wget -q -O /root/.config/rclone/rclone.conf "${REPO}/rclone.conf"

systemctl restart ws-stunnel >/dev/null 2>&1

# --- HOTFIX: APPLY DROPBEAR, HAPROXY, DAN BANNER FIX PADA SERVER YANG SUDAH JALAN ---

echo -e "[ ${GREEN}INFO${NC} ] Menerapkan patch & membersihkan cron..."

# Hapus backup ganda bawaan dari instalasi lama
sed -i '/root backup/d' /etc/crontab
sed -i '/root \/usr\/bin\/backup/d' /etc/crontab

# Hapus auto-reboot paksa dari instalasi lama
sed -i '/root reboot/d' /etc/crontab
sed -i '/root \/usr\/bin\/reboot/d' /etc/crontab

service cron restart >/dev/null 2>&1
service cron reload >/dev/null 2>&1

echo -e "[ ${GREEN}INFO${NC} ] Menerapkan patch Dropbear & HAProxy..."
# Fix Dropbear (install paket dropbear otomatis jika sebelumnya gagal terinstall)
if ! dpkg -s dropbear >/dev/null 2>&1 || [ ! -x /usr/sbin/dropbear ] || [ ! -f /etc/init.d/dropbear ]; then
    echo -e "[ ${GREEN}INFO${NC} ] Dropbear belum terpasang, menginstall paket dropbear..."
    apt_with_retry update -y >/dev/null 2>&1 || true
    apt_with_retry install -y dropbear || echo -e "[ ${RED}ERROR${NC} ] Gagal menginstall paket dropbear."
fi
cat > /etc/default/dropbear <<-END
NO_START=0
DROPBEAR_PORT=143
DROPBEAR_EXTRA_ARGS="-b /etc/issue.net -p 109 -p 58080"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
END
systemctl unmask dropbear >/dev/null 2>&1 || true
systemctl daemon-reload >/dev/null 2>&1
systemctl enable dropbear >/dev/null 2>&1
systemctl restart dropbear >/dev/null 2>&1 || /etc/init.d/dropbear restart >/dev/null 2>&1 || true

# Ensure vnstat is installed if missing
if ! command -v vnstat >/dev/null 2>&1; then
    echo -e "[ ${GREEN}INFO${NC} ] vnStat belum terpasang, menginstall paket vnstat..."
    apt_with_retry update -y >/dev/null 2>&1 || true
    apt_with_retry install -y vnstat >/dev/null 2>&1 || true
    systemctl enable vnstat >/dev/null 2>&1 || true
    systemctl restart vnstat >/dev/null 2>&1 || true
fi

# Fix HAProxy
systemctl stop nginx >/dev/null 2>&1
apt_with_retry -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install -f -y haproxy >/dev/null 2>&1 || true

mkdir -p /run/haproxy
chown -R haproxy:haproxy /run/haproxy 2>/dev/null || true

# Cegah error "Start request repeated too quickly"
mkdir -p /etc/systemd/system/haproxy.service.d
cat > /etc/systemd/system/haproxy.service.d/override.conf << EOF
[Unit]
StartLimitIntervalSec=0

[Service]
Restart=always
RestartSec=2
EOF
systemctl daemon-reload

sed -i 's/ tfo//g' /etc/haproxy/haproxy.cfg
sed -i '/chroot/d' /etc/haproxy/haproxy.cfg
sed -i '/option httplog/d' /etc/haproxy/haproxy.cfg

# Optimasi batas TCP dan antrean untuk mencegah internet timeout/port exhaustion
# Menaikkan ulimit-n ke 250000 karena HAProxy secara internal butuh FD minimal >200051 untuk melayani 100000 koneksi
sed -i '/stats socket/i \    maxconn 100000\n    ulimit-n 250000' /etc/haproxy/haproxy.cfg
sed -i '/option dontlognull/a \    maxconn 100000\n    option tcp-smart-accept\n    option tcp-smart-connect\n    timeout tarpit 1m' /etc/haproxy/haproxy.cfg
# Mencegah duplikasi jika skrip di run berkali-kali
sed -i '/maxconn 100000/d' /etc/haproxy/haproxy.cfg
sed -i '/ulimit-n 200000/d' /etc/haproxy/haproxy.cfg
sed -i '/ulimit-n 250000/d' /etc/haproxy/haproxy.cfg
sed -i '/option tcp-smart-accept/d' /etc/haproxy/haproxy.cfg
sed -i '/option tcp-smart-connect/d' /etc/haproxy/haproxy.cfg
sed -i '/timeout tarpit 1m/d' /etc/haproxy/haproxy.cfg
sed -i '/stats socket/i \    maxconn 100000\n    ulimit-n 250000' /etc/haproxy/haproxy.cfg
sed -i '/option dontlognull/a \    maxconn 100000\n    option tcp-smart-accept\n    option tcp-smart-connect\n    timeout tarpit 1m' /etc/haproxy/haproxy.cfg


# HAProxy backend already configured correctly without send-proxy
sed -i 's/ send-proxy send-proxy send-proxy send-proxy//g' /etc/haproxy/haproxy.cfg
sed -i 's/ send-proxy//g' /etc/haproxy/haproxy.cfg

# Meneruskan traffic HTTP murni (SSE/API) ke Nginx, bukan ke Dropbear
sed -i '/acl is_http2/d' /etc/haproxy/haproxy.cfg
sed -i '/acl is_http11/d' /etc/haproxy/haproxy.cfg
sed -i '/use_backend ws_backend if is_http11/d' /etc/haproxy/haproxy.cfg

sed -i '/acl is_websocket_ssl hdr(Upgrade) -i websocket/a \    acl is_http11 ssl_fc_alpn -i http/1.1\n    acl is_http2 ssl_fc_alpn -i h2' /etc/haproxy/haproxy.cfg
sed -i '/use_backend ws_backend if is_websocket_ssl/a \    use_backend ws_backend if is_http11' /etc/haproxy/haproxy.cfg

systemctl daemon-reload >/dev/null 2>&1
systemctl enable haproxy >/dev/null 2>&1
systemctl restart haproxy >/dev/null 2>&1

# Fix Banner Issue.net (Hapus duplikasi SSHD)
if download_with_retry "${REPO}/issue.net" "/etc/issue.net"; then
    chmod +x /etc/issue.net
fi
sed -i '/Banner \/etc\/issue.net/d' /etc/ssh/sshd_config
echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
systemctl restart ssh >/dev/null 2>&1
systemctl restart sshd >/dev/null 2>&1

# Fix TCP Kernel (Mencegah port exhaustion / time_wait numpuk)
mkdir -p /etc/modules-load.d
cat > /etc/modules-load.d/conntrack.conf << 'EOF'
nf_conntrack
EOF
modprobe nf_conntrack >/dev/null 2>&1 || true

sed -i '/net.core.somaxconn/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_fin_timeout/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_max_syn_backlog/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_max_tw_buckets/d' /etc/sysctl.conf
sed -i '/net.netfilter.nf_conntrack_max/d' /etc/sysctl.conf

echo "net.core.somaxconn = 65535" >> /etc/sysctl.conf
echo "net.ipv4.tcp_fin_timeout = 15" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 65535" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_tw_buckets = 2000000" >> /etc/sysctl.conf
echo "net.netfilter.nf_conntrack_max = 2000000" >> /etc/sysctl.conf

mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-conntrack.conf << 'EOF'
net.netfilter.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
EOF
prev_rmem_default=$(sysctl -n net.core.rmem_default 2>/dev/null || echo 0)
sed -i '/^[[:space:]]*net\.core\.rmem_default[[:space:]]*=/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^[[:space:]]*net\.core\.wmem_default[[:space:]]*=/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^[[:space:]]*net\.core\.rmem_max[[:space:]]*=/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^[[:space:]]*net\.core\.wmem_max[[:space:]]*=/d' /etc/sysctl.conf 2>/dev/null || true
sed -i '/^[[:space:]]*net\.core\.netdev_max_backlog[[:space:]]*=/d' /etc/sysctl.conf 2>/dev/null || true
cat > /etc/sysctl.d/99-udp-buffer.conf << 'EOF'
net.core.rmem_default = 8388608
net.core.wmem_default = 8388608
net.core.rmem_max = 67108864
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 250000
EOF
sysctl -w net.core.rmem_default=8388608 >/dev/null 2>&1 || true
sysctl -w net.core.wmem_default=8388608 >/dev/null 2>&1 || true
sysctl -w net.core.rmem_max=67108864 >/dev/null 2>&1 || true
sysctl -w net.core.wmem_max=67108864 >/dev/null 2>&1 || true
sysctl -w net.core.netdev_max_backlog=250000 >/dev/null 2>&1 || true
sysctl -p >/dev/null 2>&1 || true
sysctl --system >/dev/null 2>&1 || true

# Enable Receive Packet Steering (RPS) across vCPUs
mkdir -p /usr/local/sbin /etc/systemd/system
cat > /usr/local/sbin/enable-rps.sh << 'RPSEOF'
#!/usr/bin/env bash
set -euo pipefail
cpus=$(nproc 2>/dev/null || echo 1)
if [ "$cpus" -le 1 ]; then
    exit 0
fi
if [ "$cpus" -gt 31 ]; then
    cpus=31
fi
mask=$(printf '%x' $(( (1 << cpus) - 1 )))
for q in /sys/class/net/*/queues/rx-*/rps_cpus; do
    case "$q" in /sys/class/net/lo/*) continue ;; esac
    [ -w "$q" ] && printf '%s' "$mask" > "$q" 2>/dev/null || true
done
RPSEOF
chmod 755 /usr/local/sbin/enable-rps.sh
cat > /etc/systemd/system/network-rps.service << 'RPSSVCEOF'
[Unit]
Description=Enable Receive Packet Steering (RPS) on NIC RX queues
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/enable-rps.sh

[Install]
WantedBy=multi-user.target
RPSSVCEOF
chmod 644 /etc/systemd/system/network-rps.service
systemctl daemon-reload >/dev/null 2>&1 || true
systemctl enable --now network-rps.service >/dev/null 2>&1 || true

# Migrate BadVPN UDPGW from screen/rc.local to dedicated systemd unit (1M FD limit, nobody UID, no QUIC stall)
sed -i '/badvpn-udpgw/d' /etc/rc.local 2>/dev/null || true
badvpn_unit_tmp=$(mktemp /tmp/badvpn-udpgw.unit.XXXXXX)
cat > "$badvpn_unit_tmp" << 'UDPGWEOF'
[Unit]
Description=BadVPN UDPGW on port %i
After=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:%i --max-clients 1000 --max-connections-for-client 1000 --client-socket-sndbuf 0 --loglevel warning
Restart=always
RestartSec=2s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
UDPGWEOF

badvpn_needs_restart=0
if [ ! -f /etc/systemd/system/badvpn-udpgw@.service ] || ! cmp -s "$badvpn_unit_tmp" /etc/systemd/system/badvpn-udpgw@.service; then
    mv -f "$badvpn_unit_tmp" /etc/systemd/system/badvpn-udpgw@.service
    chmod 644 /etc/systemd/system/badvpn-udpgw@.service
    systemctl daemon-reload >/dev/null 2>&1 || true
    badvpn_needs_restart=1
else
    rm -f "$badvpn_unit_tmp"
fi

for port in 7100 7200 7300; do
    if ! systemctl is-active --quiet "badvpn-udpgw@${port}" 2>/dev/null; then
        badvpn_needs_restart=1
    fi
done
if [ "$(pgrep -xc badvpn-udpgw 2>/dev/null || echo 0)" -gt 3 ]; then
    badvpn_needs_restart=1
fi

if [ "$badvpn_needs_restart" -eq 1 ]; then
    systemctl stop badvpn-udpgw@7100 badvpn-udpgw@7200 badvpn-udpgw@7300 >/dev/null 2>&1 || true
    pkill -x badvpn-udpgw >/dev/null 2>&1 || true
    screen -wipe >/dev/null 2>&1 || true
    systemctl enable --now badvpn-udpgw@7100 badvpn-udpgw@7200 badvpn-udpgw@7300 >/dev/null 2>&1 || true
else
    systemctl enable badvpn-udpgw@7100 badvpn-udpgw@7200 badvpn-udpgw@7300 >/dev/null 2>&1 || true
fi

# Block outbound QUIC (UDP 443) ONLY for badvpn-udpgw (nobody) so YouTube/browsers fall back cleanly to TCP/443
if command -v iptables >/dev/null 2>&1; then
    need_iptables_save=0
    if ! iptables -C OUTPUT -p udp -m owner --uid-owner nobody --dport 443 -m comment --comment badvpn-block-quic -j REJECT --reject-with icmp-port-unreachable >/dev/null 2>&1; then
        if iptables -A OUTPUT -p udp -m owner --uid-owner nobody --dport 443 -m comment --comment badvpn-block-quic -j REJECT --reject-with icmp-port-unreachable >/dev/null 2>&1; then
            need_iptables_save=1
        fi
    elif [ -f /etc/iptables/rules.v4 ] && ! grep -Fq 'badvpn-block-quic' /etc/iptables/rules.v4 2>/dev/null; then
        need_iptables_save=1
    fi
    if [ "$need_iptables_save" -eq 1 ] && command -v iptables-save >/dev/null 2>&1 && [ -d /etc/iptables ]; then
        iptables-save > /etc/iptables/rules.v4.tmp 2>/dev/null || true
        if [ -s /etc/iptables/rules.v4.tmp ] && iptables-restore --test < /etc/iptables/rules.v4.tmp >/dev/null 2>&1; then
            chmod 600 /etc/iptables/rules.v4.tmp
            mv -f /etc/iptables/rules.v4.tmp /etc/iptables/rules.v4
        else
            rm -f /etc/iptables/rules.v4.tmp
        fi
    fi
fi

# Sync SlowDNS watchdog and apply new 8MB socket buffer if SlowDNS is already active (never auto-enable)
if systemctl is-active --quiet slowdns.service 2>/dev/null; then
    if [ -x /usr/bin/slowdns ]; then
        /usr/bin/slowdns sync-watchdog >/dev/null 2>&1 || true
    fi
    if [ "${prev_rmem_default:-0}" -lt 8388608 ] 2>/dev/null; then
        systemctl restart slowdns.service >/dev/null 2>&1 || true
    fi
fi

# SlowDNS Handshake Optimization & Cloudimg SSH Drop-in Cleanup
sshd_needs_reload=0
if [ -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf ]; then
    rm -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
    sshd_needs_reload=1
fi
if ! grep -q "SlowDNS Handshake Optimization" /etc/ssh/sshd_config; then
    cat >> /etc/ssh/sshd_config << 'SSHEOF'

# SlowDNS Handshake Optimization
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp256,diffie-hellman-group14-sha256,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes128-ctr,aes256-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-256,hmac-sha1
HostKeyAlgorithms ssh-ed25519,ecdsa-sha2-nistp256,rsa-sha2-256,ssh-rsa
MaxStartups 60:30:200
SSHEOF
    sshd_needs_reload=1
fi
if ! grep -qE '^[[:space:]]*MaxStartups[[:space:]]+60:30:200' /etc/ssh/sshd_config; then
    sed -i '/^[[:space:]]*MaxStartups[[:space:]]\+/d' /etc/ssh/sshd_config
    printf 'MaxStartups 60:30:200\n' >> /etc/ssh/sshd_config
    sshd_needs_reload=1
fi
if [ "$sshd_needs_reload" -eq 1 ] && sshd -t >/dev/null 2>&1; then
    systemctl reload ssh >/dev/null 2>&1 || systemctl restart ssh >/dev/null 2>&1 || systemctl restart sshd >/dev/null 2>&1 || true
fi

# Limit systemd journal to 100MB and merge user-* journals into system.journal
if [ -d /etc/systemd ]; then
    mkdir -p /etc/systemd/journald.conf.d
    cat > /etc/systemd/journald.conf.d/99-limit.conf << 'JRNEOF'
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
SplitMode=none
JRNEOF
    if command -v systemctl >/dev/null 2>&1; then
        systemctl restart systemd-journald >/dev/null 2>&1 || true
    fi
    rm -f /var/log/journal/*/user-*.journal /run/log/journal/*/user-*.journal 2>/dev/null || true
    if command -v journalctl >/dev/null 2>&1; then
        journalctl --rotate >/dev/null 2>&1 || true
        journalctl --vacuum-size=100M >/dev/null 2>&1 || true
    fi
fi

# Fail2Ban protection for all SSH ports (22, 2253, 40000) with localhost whitelisted
# Use systemd backend so logcleaner clearing /var/log/auth.log never resets fail2ban tracking
if [ ! -d /etc/fail2ban ] || ! command -v fail2ban-server >/dev/null 2>&1; then
    echo -e "[ ${GREEN}INFO${NC} ] Fail2Ban belum terpasang, menginstall fail2ban & python3-systemd..."
    apt_with_retry update -y >/dev/null 2>&1 || true
    apt_with_retry install -y fail2ban python3-systemd python3-pyinotify whois || echo -e "[ ${RED}ERROR${NC} ] Gagal menginstall paket fail2ban."
fi
if [ -d /etc/fail2ban ]; then
    if ! python3 -c "import systemd.journal" >/dev/null 2>&1; then
        apt_with_retry update -y >/dev/null 2>&1 || true
        apt_with_retry install -y python3-systemd >/dev/null 2>&1 || true
    fi
    f2b_backend="auto"
    if python3 -c "import systemd.journal" >/dev/null 2>&1; then
        f2b_backend="systemd"
    fi
    cat > /etc/fail2ban/jail.local << F2BEOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = 22,2253,40000
backend = ${f2b_backend}
F2BEOF
    systemctl unmask fail2ban >/dev/null 2>&1 || true
    systemctl enable fail2ban >/dev/null 2>&1 || true
    systemctl restart fail2ban >/dev/null 2>&1 || /etc/init.d/fail2ban restart >/dev/null 2>&1 || true
fi

# Fix Nginx Xray Routing Proxy (agar Vmess/Vless/Trojan bisa connect dari port 443)
# Preserve custom aliases independently when rewriting the base template.
mkdir -p /etc/nginx/conf.d
touch /etc/nginx/conf.d/xray-custom-paths.inc
chmod 644 /etc/nginx/conf.d/xray-custom-paths.inc
domain=$(cat /etc/xray/domain)
cat >/etc/nginx/conf.d/xray.conf <<EOF
server {
    listen 1010 so_keepalive=on reuseport;
    server_name 127.0.0.1 localhost \$domain;

    # User Optimization
    client_body_buffer_size 200K;
    client_header_buffer_size 2k;
    client_max_body_size 10M;
    large_client_header_buffers 3 1k;
    client_header_timeout 360s;
    keepalive_timeout 360s;

    root /home/vps/public_html;

    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10015;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ^~ /api/monitoring/stream {
        proxy_pass http://127.0.0.1:5890/api/monitoring/stream;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_cache off;
        chunked_transfer_encoding off;
        proxy_read_timeout 24h;
    }

    # Additive custom WebSocket aliases; default routes below remain unchanged.
    include /etc/nginx/conf.d/xray-custom-paths.inc;

    location ~ /vless {
        if (\$http_upgrade != "Websocket") {
            rewrite /(.*) /vless break;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ~ /vmess {
        if (\$http_upgrade != "Websocket") {
            rewrite /(.*) /vmess break;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ~ /trojan-ws {
        if (\$http_upgrade != "Websocket") {
            rewrite /(.*) /trojan-ws break;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ~ /ss-ws {
        if (\$http_upgrade != "Websocket") {
            rewrite /(.*) /ss-ws break;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10004;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}

server {
    listen 1013 http2 so_keepalive=on reuseport;
    server_name 127.0.0.1 localhost \$domain;

    # gRPC Locations
    location ^~ /api/monitoring/stream {
        proxy_pass http://127.0.0.1:5890/api/monitoring/stream;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_buffering off;
        proxy_cache off;
        chunked_transfer_encoding off;
        proxy_read_timeout 24h;
    }

    location ^~ /vless-grpc {
        proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10005;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ^~ /vmess-grpc {
        proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10006;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ^~ /trojan-grpc {
        proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10007;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ^~ /ss-grpc {
        proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10008;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
systemctl restart nginx >/dev/null 2>&1
# --- END HOTFIX ---

# Hapus script menu backup lama yang sudah tidak digunakan
# rm -f /usr/bin/menu-bckp
# rm -f /usr/bin/bckpbot

# --- UPDATE API MODULES ONLY ---
# Hotfix: Seluruh API module create & renew kini dilengkapi dengan pembersih Carriage Return (\r)
# dan deteksi format input durasi otomatis (hari, string tanggal, UNIX timestamp detik/milidetik).
# Ini mencegah kerusakan perhitungan detik aritmetika bash yang menyebabkan expired tahun 3031-3037.
echo -e "[ ${GREEN}INFO${NC} ] Updating API Modules (with CRLF cleansing & Auto-Expiry Parser)..."
mkdir -p /usr/local/bin/api-modules
mkdir -p /etc/nevermore-api/node

update_api_module() {
    local script_name="$1"
    local verify_string="$2"
    local tmp_file="/tmp/${script_name}"
    local target_file="/usr/local/bin/api-modules/${script_name}"

    echo -e "[ ${GREEN}INFO${NC} ] Updating ${script_name}..."
    download_with_retry "${REPO}/api-modules/${script_name}?v=$(date +%s)" "$tmp_file" || true

    if [ -f "$tmp_file" ] && grep -q "$verify_string" "$tmp_file"; then
        echo -e "[ ${GREEN}OK${NC} ] ${script_name} downloaded and verified."
        rm -f "$target_file"
        mv "$tmp_file" "$target_file"
        chmod +x "$target_file"
    else
        echo -e "[ ${RED}ERROR${NC} ] Failed to update ${script_name}!"
        rm -f "$tmp_file"
    fi
}

# Update API Bot Manager & Auth Gen Modules
update_api_module "api-bot-manager.sh" "Setup Telegram Bot"
update_api_module "api-auth-gen.sh" "Generate API Auth Key"

# Update API Create Module
update_api_module "api-ssh-create.sh" "API Module"
update_api_module "api-slowdns-create.sh" "SlowDNS Create"
update_api_module "api-xray-create.sh" "grpc_link"

# Update API Trial Module
update_api_module "api-ssh-trial.sh" "API Module"
update_api_module "api-slowdns-trial.sh" "SlowDNS Trial"
update_api_module "api-xray-trial.sh" "grpc_link"

# Update API Status Modules
update_api_module "api-ssh-status.sh" "status_account"
update_api_module "api-slowdns-status.sh" "status_account"
update_api_module "api-xray-status.sh" "status_account"

# Update API Renew Module
update_api_module "api-ssh-renew.sh" "API Module"
update_api_module "api-slowdns-renew.sh" "SlowDNS Renew"
update_api_module "api-xray-renew.sh" "new_quota"

# Update API Delete Module
update_api_module "api-ssh-delete.sh" "API Module"
update_api_module "api-slowdns-delete.sh" "SlowDNS Delete"
update_api_module "api-xray-delete.sh" "API Module"

echo -e "[ ${GREEN}INFO${NC} ] Updating API Server Backend..."
download_with_retry "${REPO}/api/server.js?v=$(date +%s)" "/etc/nevermore-api/node/server.js" || true

echo -e "[ ${GREEN}INFO${NC} ] Fixing Dependencies & Restarting API Service..."
cd /etc/nevermore-api/node

# Perbaiki package.json kosong yang menyebabkan error 'Unexpected end of JSON input'
if [ ! -s "package.json" ]; then
    echo '{"name": "geovpn-api","version": "1.0.0","description": "VPN API","main": "server.js","dependencies": {"cors": "^2.8.5","express": "^4.18.2"}}' > package.json
fi

npm install >/dev/null 2>&1

# Unmask in case it was masked by failed installations
systemctl unmask api-backend >/dev/null 2>&1

# Ensure service file exists before restarting
if [ ! -f "/etc/systemd/system/api-backend.service" ]; then
    download_with_retry "${REPO}/api/api-backend.service" "/etc/systemd/system/api-backend.service" || true
    systemctl daemon-reload >/dev/null 2>&1
    systemctl enable api-backend >/dev/null 2>&1
fi

systemctl restart geovpn-api >/dev/null 2>&1 || systemctl restart api-backend >/dev/null 2>&1
echo -e "[ ${GREEN}OK${NC} ] API Service restarted."
echo -e "[ ${GREEN}INFO${NC} ] API Modules Update Completed."

# 3. Terapkan Fix 'Clear Ghosting' (Scrollback Buffer Wipe)
# Mengganti 'clear' biasa dengan 'clear && printf "\033[3J"' pada script yang didownload
echo -e "[ ${GREEN}INFO${NC} ] Menerapkan fix terminal ghosting..."

files_to_fix=(
    "/usr/bin/menu-vless"
    "/usr/bin/menu-trojan"
    "/usr/bin/menu-ssh"
    "/usr/bin/menu-vmess"
    "/usr/bin/menu-ss"
    "/usr/bin/cek-trafik"
    "/usr/bin/cek-expired"
    "/usr/bin/menu"
    "/usr/bin/backup"
    "/usr/bin/restore"
    "/usr/bin/running"
    "/usr/bin/restart"
)

for file in "${files_to_fix[@]}"; do
    if [ -f "$file" ]; then
        sed -i "s/\bclear\b/clear \&\& printf '\\\033[3J'/g" "$file"
    fi
done

echo -e "[ ${GREEN}INFO${NC} ] Update Selesai!"
echo -e "[ ${GREEN}INFO${NC} ] Menu Footer Layout telah di-update."
echo -e "[ ${GREEN}INFO${NC} ] Script Auto-Kill SSH/Dropbear telah diperbarui."
echo -e "[ ${GREEN}INFO${NC} ] Timezone server sekarang: $(date)"
