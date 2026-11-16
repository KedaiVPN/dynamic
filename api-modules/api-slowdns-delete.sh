#!/bin/bash
# API Module: SlowDNS Delete (All-in-One: SSH + VMess + VLess)
# Args: user

user="$1"

if [[ -z "$user" ]]; then
  echo '{"status": "error", "message": "Missing username"}'
  exit 1
fi

if ! id "$user" >/dev/null 2>&1; then
  echo '{"status": "error", "message": "User does not exist"}'
  exit 1
fi

# 1. Delete Linux System User
userdel -f "$user" >/dev/null 2>&1

# 2. Remove SSH records
sed -i "/^$user ssh /d" /etc/expired-users.db
sed -i "/^$user /d" /etc/ssh/limit-user.conf

# 3. Remove Xray VMess & VLess client blocks (same markers as terminal del-slowdns.sh)
if [ -f /etc/xray/config.json ]; then
    sed -i "/^ *#vms $user /,/^ *},{/d" /etc/xray/config.json
    sed -i "/^ *#vls $user /,/^ *},{/d" /etc/xray/config.json

    sed -i "/^$user vmess /d" /etc/expired-users.db
    sed -i "/^$user vless /d" /etc/expired-users.db
    sed -i "/^$user /d" "/etc/xray/limit/vmess" 2>/dev/null
    sed -i "/^$user /d" "/etc/xray/limit/vless" 2>/dev/null

    systemctl restart xray >/dev/null 2>&1 || true
fi

cat <<EOF
{
  "status": "success",
  "message": "Account deleted successfully"
}
EOF
