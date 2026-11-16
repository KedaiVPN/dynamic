#!/bin/bash
# API Module: SlowDNS Trial (All-in-One: SSH + VMess + VLess)
# Args: none

# Load and verify SlowDNS configuration
if [[ -r /usr/lib/slowdns-config.sh ]]; then
    # shellcheck disable=SC1091
    source /usr/lib/slowdns-config.sh
    slowdns_load_config
elif [[ -r "$(dirname "$0")/../slowdns-config.sh" ]]; then
    # shellcheck disable=SC1091
    source "$(dirname "$0")/../slowdns-config.sh"
    slowdns_load_config
else
    echo '{"status": "error", "message": "SlowDNS configuration not found on server"}'
    exit 1
fi

if ! slowdns_is_active; then
  echo '{"status": "error", "message": "SlowDNS service is not active on this server"}'
  exit 1
fi

# Load Custom WS Paths
if [[ -r /usr/lib/xray-paths.sh ]]; then
    # shellcheck disable=SC1091
    . /usr/lib/xray-paths.sh
else
    VMESS_WS_PATH="/vmess"
    VLESS_WS_PATH="/vless"
fi

rand_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)
user="trialDNS${rand_suffix}"
pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)
duration_min=30

now=$(date +%s)
exp_sec=$((duration_min * 60))
exp_timestamp=$((now + exp_sec))
sys_exp_date=$(date -d "+1 day" +"%Y-%m-%d")

# 1. Create SSH User
useradd -e "$sys_exp_date" -s /bin/false -M "$user" >/dev/null 2>&1
echo -e "${pass}\n${pass}\n" | passwd "$user" >/dev/null 2>&1

echo "$user ssh $exp_timestamp" >> /etc/expired-users.db

limit_file="/etc/ssh/limit-user.conf"
mkdir -p /etc/ssh
echo "$user 1" >> "$limit_file"

# 2. Create Xray VMess & VLess Client (same UUID)
uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || true)
if [[ -z "$uuid" ]]; then
    uuid=$(od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}')
fi

vmess_link=""
vless_link=""

if [ -f /etc/xray/config.json ]; then
    sed -i '/#vmess$/a\#vms '"$user $sys_exp_date"'\
},{"id": "'"$uuid"'","alterId": 0,"email": "'"$user"'"' /etc/xray/config.json

    sed -i '/#vless$/a\#vls '"$user $sys_exp_date"'\
},{"id": "'"$uuid"'","email": "'"$user"'"' /etc/xray/config.json

    echo "$user vmess $exp_timestamp" >> /etc/expired-users.db
    echo "$user vless $exp_timestamp" >> /etc/expired-users.db

    limit_dir="/etc/xray/limit"
    mkdir -p "$limit_dir"
    echo "$user $uuid $sys_exp_date 0 0" >> "${limit_dir}/vmess"
    echo "$user $uuid $sys_exp_date 0 0" >> "${limit_dir}/vless"

    systemctl restart xray >/dev/null 2>&1 || true

    # Generate VMess NTLS Link (port 80, non-TLS)
    vmess_json="{\"v\":\"2\",\"ps\":\"SLOWDNS_VMESS_${user}\",\"add\":\"${SLOWDNS_DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"${VMESS_WS_PATH}\",\"type\":\"none\",\"host\":\"${SLOWDNS_DOMAIN}\",\"tls\":\"none\"}"
    vmess_link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"

    # Generate VLess NTLS Link (port 80, non-TLS)
    vless_link="vless://${uuid}@${SLOWDNS_DOMAIN}:80?type=ws&encryption=none&security=none&host=${SLOWDNS_DOMAIN}&path=${VLESS_WS_PATH}#SLOWDNS_VLESS_${user}"
fi

cat <<EOF
{
  "status": "success",
  "message": "Trial account created",
  "data": {
    "username": "$user",
    "password": "$pass",
    "uuid": "$uuid",
    "domain": "$SLOWDNS_DOMAIN",
    "ns_domain": "$SLOWDNS_NS_DOMAIN",
    "pubkey": "$SLOWDNS_PUBKEY",
    "dns": "$SLOWDNS_DOMAIN",
    "expired": "30 Minutes",
    "ip_limit": "1",
    "quota": "0",
    "vmess_nontls_link": "$vmess_link",
    "vless_nontls_link": "$vless_link"
  }
}
EOF
