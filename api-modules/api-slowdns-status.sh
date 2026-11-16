#!/bin/bash
# API Module: SlowDNS Status (All-in-One: SSH + VMess + VLess)
# Args: user

user="$1"

if [[ -z "$user" ]]; then
  echo '{"status": "error", "message": "Missing required arguments"}'
  exit 1
fi

# Check if user exists
if ! id "$user" >/dev/null 2>&1; then
  echo '{"status": "error", "message": "User not found"}'
  exit 1
fi

# Check Lock Status
status_output=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
if [[ "$status_output" == "L" ]]; then
    status_account="LOCKED"
else
    status_account="UNLOCKED"
fi

# Get IP limit from /etc/ssh/limit-user.conf
limit_file="/etc/ssh/limit-user.conf"
iplimit=$(awk -v u="$user" '$1==u {print $2}' "$limit_file" 2>/dev/null)
if [[ -z "$iplimit" ]]; then
    iplimit="0" # No limit or default
fi

# Get expiry from /etc/expired-users.db (ssh protocol row)
exp_timestamp=$(awk -v u="$user" '$1==u && $2=="ssh" {print $3}' /etc/expired-users.db 2>/dev/null | head -n 1)
if [[ -n "$exp_timestamp" ]]; then
    exp_date=$(date -d "@$exp_timestamp" +"%Y-%m-%d")
else
    # Fallback to chage if not found in db
    exp_date=$(chage -l "$user" | grep "Account expires" | awk -F': ' '{print $2}')
    if [[ "$exp_date" == "never" ]]; then
        exp_date="never"
    else
        exp_date=$(date -d "$exp_date" +"%Y-%m-%d" 2>/dev/null || echo "unknown")
    fi
fi

# Check Xray UUID registration (all-in-one)
uuid=""
vmess_registered=false
vless_registered=false
if [ -f /etc/xray/config.json ]; then
    uuid=$(sed -n "/#vms $user /,/^ *},{/p" /etc/xray/config.json | grep -o '"id": *"[0-9a-f-]*"' | head -1 | cut -d'"' -f4)
    grep -q "#vms $user " /etc/xray/config.json && vmess_registered=true
    grep -q "#vls $user " /etc/xray/config.json && vless_registered=true
fi

# JSON Response
cat <<EOF
{
  "status": "success",
  "data": {
    "protocol": "slowdns",
    "username": "$user",
    "status_account": "$status_account",
    "ip_limit": "$iplimit",
    "expired": "$exp_date",
    "uuid": "$uuid",
    "vmess_registered": $vmess_registered,
    "vless_registered": $vless_registered
  }
}
EOF
