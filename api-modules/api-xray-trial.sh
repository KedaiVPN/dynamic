#!/bin/bash
# API Module: Xray Trial
# Args: protocol
# Updated for complete link formats (gRPC, Trojan-Go) and consistent usernames

protocol="$1"
duration_min=30

if [[ -z "$protocol" ]]; then
  echo '{"status": "error", "message": "Missing protocol"}'
  exit 1
fi

rand_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)

# Define User Suffix based on Protocol
case $protocol in
  vmess)
    user="trialVM${rand_suffix}"
    ;;
  vless)
    user="trialVL${rand_suffix}"
    ;;
  trojan)
    user="trialTR${rand_suffix}"
    ;;
  *)
    user="trial${rand_suffix}"
    ;;
esac

# UUID
uuid=$(cat /proc/sys/kernel/random/uuid)

# Expiry
now=$(date +%s)
exp_sec=$((duration_min * 60))
exp_timestamp=$((now + exp_sec))
# Display expiry as +30min time
exp_date=$(date -d "+$duration_min minutes" +"%H:%M:%S")

domain=$(cat /etc/xray/domain 2>/dev/null)
if [[ -z "$domain" ]]; then domain=$(curl -s https://ipinfo.io/ip/); fi

# Quota/Limit
mkdir -p /etc/xray/limit
limit_file="/etc/xray/limit/$protocol"
# Trial limit: 1 IP, 1 GB (or as configured)
echo "$user $uuid $exp_date 1 1" >> "$limit_file"

# DB
echo "$user $protocol $exp_timestamp" >> /etc/expired-users.db

# Insert Config & Generate Links
case $protocol in
  vmess)
    sed -i '/#vmess$/a\#vms '"$user $exp_date"'\
},{"id": "'""$uuid""'","alterId": 0,"email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#vmessgrpc$/a\#vmsg '"$user $exp_date"'\
},{"id": "'""$uuid""'","alterId": 0,"email": "'""$user""'"' /etc/xray/config.json

    json_tls="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${domain}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"type\":\"none\",\"host\":\"${domain}\",\"tls\":\"tls\"}"
    json_nontls="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${domain}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess\",\"type\":\"none\",\"host\":\"${domain}\",\"tls\":\"none\"}"
    json_grpc="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${domain}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"grpc\",\"path\":\"vmess-grpc\",\"type\":\"none\",\"host\":\"${domain}\",\"tls\":\"tls\"}"
    
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

    link_tls="vless://${uuid}@${domain}:443?type=ws&encryption=none&security=tls&host=${domain}&path=/vless&allowInsecure=1&sni=${domain}#${user}"
    link_nontls="vless://${uuid}@${domain}:80?type=ws&encryption=none&security=none&host=${domain}&path=/vless#${user}"
    link_grpc="vless://${uuid}@${domain}:443?security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${domain}#${user}"
    
    data_out="\"vless_tls_link\": \"$link_tls\", \"vless_nontls_link\": \"$link_nontls\", \"vless_grpc_link\": \"$link_grpc\", \"uuid\": \"$uuid\""
    ;;
  trojan)
    sed -i '/#trojanws$/a\#tr '"$user $exp_date"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#trojangrpc$/a\#trg '"$user $exp_date"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json

    link_tls="trojan://${uuid}@${domain}:443?path=%2Ftrojan-ws&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
    link_go="trojan-go://${uuid}@${domain}:443?path=%2Ftrojan-ws&security=tls&host=${domain}&type=ws&sni=${domain}#${user}"
    link_grpc="trojan://${uuid}@${domain}:443?security=tls&type=grpc&serviceName=trojan-grpc&sni=${domain}#${user}"
    
    data_out="\"trojan_tls_link\": \"$link_tls\", \"trojan_go_link\": \"$link_go\", \"trojan_grpc_link\": \"$link_grpc\", \"uuid\": \"$uuid\""
    ;;
esac

systemctl restart xray >/dev/null 2>&1

cat <<EOF
{
  "status": "success",
  "message": "Trial account created",
  "data": {
    "username": "$user",
    "domain": "$domain",
    "expired": "30 Minutes",
    "ip_limit": "1",
    "quota": "1",
    $data_out
  }
}
EOF
