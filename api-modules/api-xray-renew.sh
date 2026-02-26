#!/bin/bash
# API Module: Xray Renew
# Args: protocol user add_days

protocol="$1"
user="$2"
add_days="$3"

if [[ -z "$protocol" || -z "$user" || -z "$add_days" ]]; then
  echo '{"status": "error", "message": "Missing required arguments"}'
  exit 1
fi

# Find current expiry from DB
# DB Line: user protocol timestamp
db_line=$(grep "^$user $protocol " /etc/expired-users.db)
if [[ -z "$db_line" ]]; then
  # Try finding just user
  db_line=$(grep "^$user " /etc/expired-users.db | grep "$protocol")
fi

if [[ -z "$db_line" ]]; then
     # Default to now if not found (restoring?)
     current_exp_sec=$(date +%s)
else
     current_exp_sec=$(echo "$db_line" | awk '{print $3}')
fi

now=$(date +%s)
if [[ $current_exp_sec -lt $now ]]; then
    base_sec=$now
else
    base_sec=$current_exp_sec
fi

add_sec=$((add_days * 86400))
new_exp_sec=$((base_sec + add_sec))
new_exp_date=$(date -d "@$new_exp_sec" +"%Y-%m-%d")
new_exp_display=$(date -d "@$new_exp_sec" +"%Y-%m-%d")

# Update DB
sed -i "/^$user $protocol /d" /etc/expired-users.db
echo "$user $protocol $new_exp_sec" >> /etc/expired-users.db

# Update Config Comment (Optional but good practice)
# Markers: #vms, #vmsg, #vls, #vlsg, #tr, #trg
case $protocol in
    vmess)
        sed -i "s/#vms $user .*/#vms $user $new_exp_date/" /etc/xray/config.json
        sed -i "s/#vmsg $user .*/#vmsg $user $new_exp_date/" /etc/xray/config.json
        ;;
    vless)
        sed -i "s/#vls $user .*/#vls $user $new_exp_date/" /etc/xray/config.json
        sed -i "s/#vlsg $user .*/#vlsg $user $new_exp_date/" /etc/xray/config.json
        ;;
    trojan)
        sed -i "s/#tr $user .*/#tr $user $new_exp_date/" /etc/xray/config.json
        sed -i "s/#trg $user .*/#trg $user $new_exp_date/" /etc/xray/config.json
        ;;
esac

# Update Limit File (Format: user uuid exp quota usage)
# We need to preserve uuid and quota
limit_file="/etc/xray/limit/$protocol"
if [[ -f "$limit_file" ]]; then
    # Read existing line
    line=$(grep "^$user " "$limit_file")
    if [[ -n "$line" ]]; then
        uuid=$(echo "$line" | awk '{print $2}')
        quota=$(echo "$line" | awk '{print $4}')
        usage=$(echo "$line" | awk '{print $5}')
        sed -i "/^$user /d" "$limit_file"
        echo "$user $uuid $new_exp_date $quota $usage" >> "$limit_file"
    fi
fi

systemctl restart xray >/dev/null 2>&1

cat <<EOF
{
  "status": "success",
  "message": "Account renewed successfully",
  "data": {
    "expired": "$new_exp_display"
  }
}
EOF
