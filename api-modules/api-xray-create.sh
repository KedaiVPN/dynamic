#!/bin/bash
# API Module: Xray Create
# Args: protocol user exp_days quota iplimit
# Protocol: vmess, vless, trojan

protocol="$1"
raw_user="$2"
exp_days="$3"
quota="$4"
iplimit="$5"

if [[ -z "$protocol" || -z "$raw_user" || -z "$exp_days" ]]; then
  echo '{"status": "error", "message": "Missing required arguments"}'
  exit 1
fi

# Apply Format: User(PROTOCOL)(3 Random Chars)
rand_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)

case $protocol in
  vmess)
    user="${raw_user}VM${rand_suffix}"
    ;;
  vless)
    user="${raw_user}VL${rand_suffix}"
    ;;
  trojan)
    user="${raw_user}TR${rand_suffix}"
    ;;
  *)
    echo '{"status": "error", "message": "Invalid protocol"}'
    exit 1
    ;;
esac

# Check if user exists
if grep -q "\"email\": \"$user\"" /etc/xray/config.json; then
  echo '{"status": "error", "message": "User already exists"}'
  exit 1
fi

# Generate UUID
uuid=$(cat /proc/sys/kernel/random/uuid)

# Expiry
exp_date=$(date -d "+${exp_days} days" +"%Y-%m-%d")
now=$(date +%s)
exp_seconds=$((exp_days * 86400))
exp_timestamp=$((now + exp_seconds))

# Domain
domain=$(cat /etc/xray/domain 2>/dev/null)
if [[ -z "$domain" ]]; then domain=$(curl -s https://ipinfo.io/ip/); fi

# Quota/Limit Files
mkdir -p /etc/xray/limit
limit_file="/etc/xray/limit/$protocol"
lock_file="/etc/xray/limit/lock-$protocol"
touch "$limit_file" "$lock_file"
sed -i "/^$user /d" "$limit_file"

# FIX: Use $iplimit instead of hardcoded 0
if [[ -z "$iplimit" ]]; then iplimit="0"; fi
echo "$user $uuid $exp_date $quota $iplimit" >> "$limit_file"

# Expiry DB
echo "$user $protocol $exp_timestamp" >> /etc/expired-users.db

# Insert into Config & Generate Links
case $protocol in
  vmess)
    sed -i '/#vmess$/a\#vms '"$user $exp_date"'\
},{"id": "'""$uuid""'","alterId": 0,"email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#vmessgrpc$/a\#vmsg '"$user $exp_date"'\
},{"id": "'""$uuid""'","alterId": 0,"email": "'""$user""'"' /etc/xray/config.json

    # Link Generation (Matches add-ws.sh)
    json_tls="{\"v\":\"2\",\"ps\":\"VMESS_TLS_${user}\",\"add\":\"${domain}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"type\":\"none\",\"host\":\"${domain}\",\"tls\":\"tls\"}"
    json_nontls="{\"v\":\"2\",\"ps\":\"VMESS_NTLS_${user}\",\"add\":\"${domain}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"type\":\"none\",\"host\":\"${domain}\",\"tls\":\"none\"}"
    json_grpc="{\"v\":\"2\",\"ps\":\"VMESS_GRPC_${user}\",\"add\":\"${domain}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"grpc\",\"path\":\"vmess-grpc\",\"type\":\"none\",\"host\":\"${domain}\",\"tls\":\"tls\"}"
    
    link_tls="vmess://$(echo -n "$json_tls" | base64 -w 0)"
    link_nontls="vmess://$(echo -n "$json_nontls" | base64 -w 0)"
    link_grpc="vmess://$(echo -n "$json_grpc" | base64 -w 0)"

    data_out="\"vmess_tls_link\": \"$link_tls\", \"vmess_nontls_link\": \"$link_nontls\", \"vmess_grpc_link\": \"$link_grpc\", \"uuid\": \"$uuid\""
    ;;

  vless)
    sed -i '/#vless$/a\#vls '"$user $exp_date"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#vlessgrpc$/a\#vlsg '"$user $exp_date"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json

    # Link Generation (Matches add-vless.sh)
    link_tls="vless://${uuid}@${domain}:443?type=ws&encryption=none&security=tls&host=${domain}&path=/vless&allowInsecure=1&sni=${domain}#XRAY_VLESS_TLS_${user}"
    link_nontls="vless://${uuid}@${domain}:80?type=ws&encryption=none&security=none&host=${domain}&path=/vless#XRAY_VLESS_NTLS_${user}"
    link_grpc="vless://${uuid}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${domain}#VLESS_GRPC_${user}"
    
    data_out="\"vless_tls_link\": \"$link_tls\", \"vless_nontls_link\": \"$link_nontls\", \"vless_grpc_link\": \"$link_grpc\", \"uuid\": \"$uuid\""
    ;;

  trojan)
    sed -i '/#trojanws$/a\#tr '"$user $exp_date"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#trojangrpc$/a\#trg '"$user $exp_date"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json

    # Link Generation (Matches add-tr.sh)
    # Note: add-tr.sh reads port from log-install.txt, usually 443 for WS/GRPC
    link_tls="trojan://${uuid}@${domain}:443?path=%2Ftrojan-ws&security=tls&host=${domain}&type=ws&sni=${domain}#TROJAN_WS_${user}"
    link_go="trojan-go://${uuid}@${domain}:443?path=%2Ftrojan-ws&security=tls&host=${domain}&type=ws&sni=${domain}#TROJANGO_${user}"
    link_grpc="trojan://${uuid}@${domain}:443?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#TROJAN_GRPC_${user}"

    data_out="\"trojan_tls_link\": \"$link_tls\", \"trojan_go_link\": \"$link_go\", \"trojan_grpc_link\": \"$link_grpc\", \"uuid\": \"$uuid\""
    ;;
esac

# Restart Xray
systemctl restart xray >/dev/null 2>&1

cat <<EOF
{
  "status": "success",
  "message": "Account created successfully",
  "data": {
    "username": "$user",
    "domain": "$domain",
    "expired": "$exp_date",
    "ip_limit": "$iplimit",
    "quota": "$quota",
    $data_out
  }
}
EOF
