#!/bin/bash
# API Module: SlowDNS Create (All-in-One: SSH + VMess + VLess)
# Args: user pass exp_days quota iplimit

raw_user="$1"
pass="$2"
exp_days=$(echo "$3" | tr -d '\r\n')
quota="$4"
iplimit="$5"

if [[ -z "$raw_user" || -z "$pass" || -z "$exp_days" ]]; then
  echo '{"status": "error", "message": "Missing required arguments"}'
  exit 1
fi

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

# Apply Format: UserDNS(3 Random Chars)
rand_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)
user="${raw_user}DNS${rand_suffix}"

# Check if user exists (Linux AND Xray config)
if id "$user" >/dev/null 2>&1 || grep -wq "$user" /etc/xray/config.json 2>/dev/null; then
  echo '{"status": "error", "message": "User already exists (collision)"}'
  exit 1
fi

# Parse Expiry (supports days, date string, and unix timestamp)
now=$(date +%s)
if [[ "$exp_days" =~ ^[0-9]+$ ]]; then
  if [ ${#exp_days} -ge 10 ]; then
    # Unix timestamp
    if [ ${#exp_days} -eq 13 ]; then
      # milliseconds
      exp_timestamp=$((exp_days / 1000))
    else
      # seconds
      exp_timestamp=$exp_days
    fi
    exp_date=$(date -d "@$exp_timestamp" +"%Y-%m-%d" 2>/dev/null)
  else
    # Number of days
    exp_date=$(date -d "+${exp_days} days" +"%Y-%m-%d" 2>/dev/null)
    exp_timestamp=$((now + exp_days * 86400))
  fi
else
  # Date string
  exp_timestamp=$(date -d "$exp_days" +%s 2>/dev/null)
  if [ -n "$exp_timestamp" ]; then
    exp_date=$(date -d "$exp_days" +"%Y-%m-%d" 2>/dev/null)
  else
    echo '{"status": "error", "message": "Invalid expiration date format"}'
    exit 1
  fi
fi

if [[ -z "$exp_date" ]]; then
  echo '{"status": "error", "message": "Failed to parse expiration date"}'
  exit 1
fi

# 1. Create SSH User
useradd -e "$exp_date" -s /bin/false -M "$user" >/dev/null 2>&1
echo -e "${pass}\n${pass}\n" | passwd "$user" >/dev/null 2>&1

echo "$user ssh $exp_timestamp" >> /etc/expired-users.db

# Set IP Limit
limit_file="/etc/ssh/limit-user.conf"
if [[ -n "$iplimit" && "$iplimit" -gt 0 ]]; then
    mkdir -p /etc/ssh
    if [ -f "$limit_file" ]; then
        grep -v "^$user " "$limit_file" > "${limit_file}.tmp" && mv "${limit_file}.tmp" "$limit_file"
    fi
    echo "$user $iplimit" >> "$limit_file"
fi

# 2. Create Xray VMess & VLess Client (same UUID)
uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || true)
if [[ -z "$uuid" ]]; then
    uuid=$(od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}')
fi

vmess_link=""
vless_link=""

if [ -f /etc/xray/config.json ]; then
    sed -i '/#vmess$/a\#vms '"$user $exp_date"'\
},{"id": "'"$uuid"'","alterId": 0,"email": "'"$user"'"' /etc/xray/config.json

    sed -i '/#vless$/a\#vls '"$user $exp_date"'\
},{"id": "'"$uuid"'","email": "'"$user"'"' /etc/xray/config.json

    echo "$user vmess $exp_timestamp" >> /etc/expired-users.db
    echo "$user vless $exp_timestamp" >> /etc/expired-users.db

    limit_dir="/etc/xray/limit"
    mkdir -p "$limit_dir"
    echo "$user $uuid $exp_date 0 0" >> "${limit_dir}/vmess"
    echo "$user $uuid $exp_date 0 0" >> "${limit_dir}/vless"

    systemctl restart xray >/dev/null 2>&1 || true

    # Generate VMess NTLS Link (port 80, non-TLS)
    vmess_json="{\"v\":\"2\",\"ps\":\"SLOWDNS_VMESS_${user}\",\"add\":\"${SLOWDNS_DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"${VMESS_WS_PATH}\",\"type\":\"none\",\"host\":\"${SLOWDNS_DOMAIN}\",\"tls\":\"none\"}"
    vmess_link="vmess://$(echo -n "$vmess_json" | base64 -w 0)"

    # Generate VLess NTLS Link (port 80, non-TLS)
    vless_link="vless://${uuid}@${SLOWDNS_DOMAIN}:80?type=ws&encryption=none&security=none&host=${SLOWDNS_DOMAIN}&path=${VLESS_WS_PATH}#SLOWDNS_VLESS_${user}"
fi

# JSON Response
cat <<EOF
{
  "status": "success",
  "message": "Account created successfully",
  "data": {
    "username": "$user",
    "password": "$pass",
    "uuid": "$uuid",
    "domain": "$SLOWDNS_DOMAIN",
    "ns_domain": "$SLOWDNS_NS_DOMAIN",
    "pubkey": "$SLOWDNS_PUBKEY",
    "dns": "$SLOWDNS_DOMAIN",
    "expired": "$exp_date",
    "ip_limit": "$iplimit",
    "quota": "$quota",
    "vmess_nontls_link": "$vmess_link",
    "vless_nontls_link": "$vless_link"
  }
}
EOF
