#!/bin/bash
# API Module: SSH Trial
# Args: none

rand_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)
user="trialSSH${rand_suffix}"
pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)
duration_min=30

now=$(date +%s)
exp_sec=$((duration_min * 60))
exp_timestamp=$((now + exp_sec))
sys_exp_date=$(date -d "+1 day" +"%Y-%m-%d")

useradd -e "$sys_exp_date" -s /bin/false -M "$user" >/dev/null 2>&1
echo -e "${pass}\n${pass}\n" | passwd "$user" >/dev/null 2>&1

echo "$user ssh $exp_timestamp" >> /etc/expired-users.db

limit_file="/etc/ssh/limit-user.conf"
mkdir -p /etc/ssh
echo "$user 1" >> "$limit_file"

domain=$(cat /etc/xray/domain 2>/dev/null)
if [[ -z "$domain" ]]; then domain=$(curl -s https://ipinfo.io/ip/); fi
ssh_ws=$(grep -w "SSH Websocket" /root/log-install.txt | cut -d: -f2 | awk '{print $1}')
ssh_ssl=$(grep -w "SSH SSL Websocket" /root/log-install.txt | cut -d: -f2 | awk '{print $1}')
ssl_port=$(grep -w "Stunnel5" /root/log-install.txt | cut -d: -f2 | awk '{print $1}')

cat <<EOF
{
  "status": "success",
  "message": "Trial account created",
  "data": {
    "username": "$user",
    "password": "$pass",
    "domain": "$domain",
    "expired": "30 Minutes",
    "ip_limit": "1",
    "quota": "0",
    "ssh_ws_port": "$ssh_ws",
    "ssh_ssl_port": "$ssh_ssl",
    "ssl_port": "$ssl_port"
  }
}
EOF
