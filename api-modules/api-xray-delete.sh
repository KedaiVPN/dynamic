#!/bin/bash
# API Module: Xray Delete
# Args: protocol user

protocol="$1"
user="$2"

if [[ -z "$protocol" || -z "$user" ]]; then
  echo '{"status": "error", "message": "Missing arguments"}'
  exit 1
fi

# Remove from Config
case $protocol in
    vmess)
        sed -i "/^ *#vms $user /,/^ *},{/d" /etc/xray/config.json
        sed -i "/^ *#vmsg $user /,/^ *},{/d" /etc/xray/config.json
        ;;
    vless)
        sed -i "/^ *#vls $user /,/^ *},{/d" /etc/xray/config.json
        sed -i "/^ *#vlsg $user /,/^ *},{/d" /etc/xray/config.json
        ;;
    trojan)
        sed -i "/^ *#tr $user /,/^ *},{/d" /etc/xray/config.json
        sed -i "/^ *#trg $user /,/^ *},{/d" /etc/xray/config.json
        ;;
esac

# Remove from DB and Limit
sed -i "/^$user $protocol /d" /etc/expired-users.db
sed -i "/^$user /d" "/etc/xray/limit/$protocol" 2>/dev/null

systemctl restart xray >/dev/null 2>&1

cat <<EOF
{
  "status": "success",
  "message": "Account deleted successfully"
}
EOF
