#!/bin/bash
# API Module: Xray Renew
# Args: protocol user add_days new_quota

protocol="$1"
user="$2"
add_days=$(echo "$3" | tr -d '\r\n')
new_quota="$4"

if [[ -z "$protocol" || -z "$user" || -z "$add_days" || -z "$new_quota" ]]; then
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

# Fallback if DB contains non-numeric timestamp
if ! [[ "$current_exp_sec" =~ ^[0-9]+$ ]]; then
    converted_ts=$(date -d "$current_exp_sec" +%s 2>/dev/null)
    if [ -n "$converted_ts" ] && [[ "$converted_ts" =~ ^[0-9]+$ ]]; then
        current_exp_sec="$converted_ts"
    else
        current_exp_sec=$(date +%s)
    fi
fi

now=$(date +%s)
if [[ $current_exp_sec -lt $now ]]; then
    base_sec=$now
else
    base_sec=$current_exp_sec
fi

# Parse add_days (supports days, date string, and unix timestamp)
if [[ "$add_days" =~ ^[0-9]+$ ]]; then
  if [ ${#add_days} -ge 10 ]; then
    # Unix timestamp (absolute target)
    if [ ${#add_days} -eq 13 ]; then
      new_exp_sec=$((add_days / 1000))
    else
      new_exp_sec=$add_days
    fi
  else
    # Number of days to add
    add_sec=$((add_days * 86400))
    new_exp_sec=$((base_sec + add_sec))
  fi
else
  # Date string (absolute target)
  parsed_ts=$(date -d "$add_days" +%s 2>/dev/null)
  if [ -n "$parsed_ts" ]; then
    new_exp_sec=$parsed_ts
  else
    echo '{"status": "error", "message": "Invalid renewal date format"}'
    exit 1
  fi
fi

new_exp_date=$(date -d "@$new_exp_sec" +"%Y-%m-%d" 2>/dev/null)
if [[ -z "$new_exp_date" ]]; then
  echo '{"status": "error", "message": "Failed to parse renewal date"}'
  exit 1
fi
new_exp_display="$new_exp_date"

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
# We need to preserve uuid but update quota and reset usage to 0
limit_file="/etc/xray/limit/$protocol"
lock_file="/etc/xray/limit/lock-$protocol"

# Unlock user if locked
if [[ -f "$lock_file" ]] && grep -q "^$user " "$lock_file"; then
    uuid=$(grep "^$user " "$lock_file" | awk '{print $2}')

    # Update limit file
    sed -i "/^$user /d" "$limit_file"
    echo "$user $uuid $new_exp_date $new_quota 0" >> "$limit_file"

    # Inject back to config based on protocol
    case $protocol in
        vmess)
            sed -i '/#vmess$/a\#vms '"$user $new_exp_date"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
            sed -i '/#vmessworry$/a\### '"$user $new_exp_date"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
            sed -i '/#vmesskuota$/a\### '"$user $new_exp_date"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
            sed -i '/#vmessgrpc$/a\#vmsg '"$user $new_exp_date"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
            ;;
        vless)
            sed -i '/#vless$/a\#vls '"$user $new_exp_date"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
            sed -i '/#vlessgrpc$/a\#vlsg '"$user $new_exp_date"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
            ;;
        trojan)
            sed -i '/#trojanws$/a\#tr '"$user $new_exp_date"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
            sed -i '/#trojangrpc$/a\#trg '"$user $new_exp_date"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
            ;;
    esac

    sed -i "/^$user /d" "$lock_file"
else
    # Not locked, just update limit file
    if [[ -f "$limit_file" ]]; then
        line=$(grep "^$user " "$limit_file")
        if [[ -n "$line" ]]; then
            uuid=$(echo "$line" | awk '{print $2}')
            sed -i "/^$user /d" "$limit_file"
            echo "$user $uuid $new_exp_date $new_quota 0" >> "$limit_file"
        fi
    fi
fi

# Reset internal xray usage counter & hapus akumulasi lama
/usr/local/bin/xray api stats --server=127.0.0.1:10085 --name "user>>>${user}>>>traffic>>>uplink" --reset > /dev/null 2>&1
/usr/local/bin/xray api stats --server=127.0.0.1:10085 --name "user>>>${user}>>>traffic>>>downlink" --reset > /dev/null 2>&1
sed -i "/^${user} /d" "/etc/xray/limit/usage-$protocol" >/dev/null 2>&1

systemctl restart xray >/dev/null 2>&1

cat <<EOF
{
  "status": "success",
  "message": "Account renewed successfully",
  "data": {
    "expired": "$new_exp_display",
    "quota": "$new_quota"
  }
}
EOF
