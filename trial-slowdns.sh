#!/bin/bash
# =========================================
# Quick Setup | Script Komplit Untuk VPS
# Edition : Stable Edition V1.0
# Auther  : Adit Ardiansyah
# (C) Copyright 2021-2026 By KedaiVPN
# =========================================
clear && printf '\033[3J'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export LIGHT='\033[0;37m'
export NC='\033[0m'
export EROR="[${RED} EROR ${NC}]"

# Root Checking
if [ "${EUID}" -ne 0 ]; then
    echo -e "${EROR} Please Run This Script As Root User !"
    exit 1
fi

# License Checking
if [ -f /usr/local/bin/cek-lisensi ]; then
    /usr/local/bin/cek-lisensi --check-only || exit 1
fi

# Load SlowDNS Config
if [[ -r /usr/lib/slowdns-config.sh ]]; then
    # shellcheck disable=SC1091
    source /usr/lib/slowdns-config.sh
    slowdns_load_config
elif [[ -r "$(dirname "$0")/slowdns-config.sh" ]]; then
    # shellcheck disable=SC1091
    source "$(dirname "$0")/slowdns-config.sh"
    slowdns_load_config
fi

if ! slowdns_is_active; then
    echo -e "${EROR} Service SlowDNS belum aktif di server ini!"
    echo -e "Silakan aktifkan SlowDNS terlebih dahulu melalui menu SlowDNS [1]."
    read -n 1 -s -r -p "Press any key to back on menu"
    menu
    exit 1
fi

# Load Custom WS Paths
if [[ -r /usr/lib/xray-paths.sh ]]; then
    # shellcheck disable=SC1091
    . /usr/lib/xray-paths.sh
elif [[ -r "$(dirname "$0")/xray-paths.sh" ]]; then
    # shellcheck disable=SC1091
    . "$(dirname "$0")/xray-paths.sh"
else
    VMESS_WS_PATH="/vmess"
    VLESS_WS_PATH="/vless"
fi

domain=$(cat /etc/xray/domain 2>/dev/null || cat /etc/v2ray/domain 2>/dev/null || true)
if [[ -z "$domain" ]]; then
    domain="$SLOWDNS_DOMAIN"
fi
if [[ -z "$domain" ]]; then
    domain=$(curl -s ipinfo.io/ip || true)
fi

ns_domain="${SLOWDNS_NS_DOMAIN:-ns-$domain}"
pubkey="${SLOWDNS_PUBKEY:-}"
dns_resolver="${SLOWDNS_RESOLVER:-$domain}"

rand_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)
user="trialDNS${rand_suffix}"
pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4)

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m      Trial SlowDNS Account        \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -p "Masa Aktif (Menit): " masa_aktif_menit
if [[ -z "$masa_aktif_menit" || ! "$masa_aktif_menit" =~ ^[0-9]+$ ]]; then
    masa_aktif_menit=30
fi

now=$(date +%s)
exp_seconds=$((masa_aktif_menit * 60))
exp_timestamp=$((now + exp_seconds))
sys_exp_date=$(date -d "+1 day" +"%Y-%m-%d")

# 1. Create SSH User
useradd -e "$sys_exp_date" -s /bin/false -M "$user" >/dev/null 2>&1
echo -e "$pass\n$pass\n" | passwd "$user" &>/dev/null

echo "$user ssh $exp_timestamp" >> /etc/expired-users.db

limit_file="/etc/ssh/limit-user.conf"
mkdir -p /etc/ssh
if [ -f "$limit_file" ]; then
    awk -v u="$user" '$1!=u' "$limit_file" > "${limit_file}.tmp" && mv "${limit_file}.tmp" "$limit_file"
fi
echo "$user 1" >> "$limit_file"

# 2. Create Xray VMess & VLess User
uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || cat /proc/sys/kernel/random/boot_id 2>/dev/null || true)
if [[ -z "$uuid" ]]; then
    uuid=$(od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}')
fi

if [ -f /etc/xray/config.json ]; then
    sed -i '/#vmess$/a\#vms '"$user $sys_exp_date"'\\\
},{"id": "'"$uuid"'","alterId": 0,"email": "'"$user"'"' /etc/xray/config.json

    sed -i '/#vless$/a\#vls '"$user $sys_exp_date"'\\\
},{"id": "'"$uuid"'","email": "'"$user"'"' /etc/xray/config.json

    echo "$user vmess $exp_timestamp" >> /etc/expired-users.db
    echo "$user vless $exp_timestamp" >> /etc/expired-users.db

    limit_dir="/etc/xray/limit"
    mkdir -p "$limit_dir"
    echo "$user $uuid $sys_exp_date 0 0" >> "${limit_dir}/vmess"
    echo "$user $uuid $sys_exp_date 0 0" >> "${limit_dir}/vless"

    systemctl restart xray >/dev/null 2>&1 || true
fi

# Ports info
opensh=$(cat /root/log-install.txt 2>/dev/null | grep -w "OpenSSH" | cut -f2 -d: | awk '{print $1}')
db=$(cat /root/log-install.txt 2>/dev/null | grep -w "Dropbear" | cut -f2 -d: | awk '{print $1,$2}')
opensh=${opensh:-22}
db=${db:-"109, 143"}

# Generate VMess NTLS Link
vmess_json=$(cat <<EOF
{
  "v": "2",
  "ps": "SLOWDNS_VMESS_${user}",
  "add": "${domain}",
  "port": "80",
  "id": "${uuid}",
  "aid": "0",
  "net": "ws",
  "path": "${VMESS_WS_PATH}",
  "type": "none",
  "host": "${domain}",
  "tls": "none"
}
EOF
)
vmess_link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"

# Generate VLess NTLS Link
vless_link="vless://${uuid}@${domain}:80?type=ws&encryption=none&security=none&host=${domain}&path=${VLESS_WS_PATH}#SLOWDNS_VLESS_${user}"

clear && printf '\033[3J'
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-user.log
echo -e "\E[0;41;36m     TRIAL SLOWDNS ALL-IN-ONE      \E[0m" | tee -a /etc/log-create-user.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-user.log
echo -e "Username       : $user" | tee -a /etc/log-create-user.log
echo -e "Password       : $pass" | tee -a /etc/log-create-user.log
echo -e "Expired On     : $masa_aktif_menit Menit" | tee -a /etc/log-create-user.log
echo -e "Limit Login    : 1 Device" | tee -a /etc/log-create-user.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-user.log
echo -e "\E[1;33mSLOWDNS SETTINGS\E[0m" | tee -a /etc/log-create-user.log
echo -e "Nameserver     : $ns_domain" | tee -a /etc/log-create-user.log
echo -e "Public Key     : $pubkey" | tee -a /etc/log-create-user.log
echo -e "DNS Resolver   : $dns_resolver" | tee -a /etc/log-create-user.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-user.log
echo -e "\E[1;33mSSH SLOWDNS\E[0m" | tee -a /etc/log-create-user.log
echo -e "Host / IP      : $domain" | tee -a /etc/log-create-user.log
echo -e "Port OpenSSH   : $opensh" | tee -a /etc/log-create-user.log
echo -e "Port Dropbear  : $db" | tee -a /etc/log-create-user.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-user.log
echo -e "\E[1;33mVMESS SLOWDNS (Port 80 Non-TLS)\E[0m" | tee -a /etc/log-create-user.log
echo -e "Path           : ${VMESS_WS_PATH}" | tee -a /etc/log-create-user.log
echo -e "Link VMess     : ${vmess_link}" | tee -a /etc/log-create-user.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-user.log
echo -e "\E[1;33mVLESS SLOWDNS (Port 80 Non-TLS)\E[0m" | tee -a /etc/log-create-user.log
echo -e "Path           : ${VLESS_WS_PATH}" | tee -a /etc/log-create-user.log
echo -e "Link VLess     : ${vless_link}" | tee -a /etc/log-create-user.log
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m" | tee -a /etc/log-create-user.log
echo "" | tee -a /etc/log-create-user.log
read -n 1 -s -r -p "Press any key to back on menu"
menu
