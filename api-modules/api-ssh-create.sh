#!/bin/bash
# API Module: SSH Create
# Args: user pass exp_days quota iplimit

raw_user="$1"
pass="$2"
exp_days="$3"
quota="$4"
iplimit="$5"

if [[ -z "$raw_user" || -z "$pass" || -z "$exp_days" ]]; then
  echo '{"status": "error", "message": "Missing required arguments"}'
  exit 1
fi

# Apply Format: UserSSH(3 Random Chars)
rand_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)
user="${raw_user}SSH${rand_suffix}"

# Check if user exists
if id "$user" >/dev/null 2>&1; then
  echo '{"status": "error", "message": "User already exists (collision)"}'
  exit 1
fi

# Set Expiry
exp_date=$(date -d "+${exp_days} days" +"%Y-%m-%d")
useradd -e "$exp_date" -s /bin/false -M "$user" >/dev/null 2>&1
echo -e "${pass}\n${pass}\n" | passwd "$user" >/dev/null 2>&1

# Add to expiry database (seconds)
now=$(date +%s)
exp_seconds=$((exp_days * 86400))
exp_timestamp=$((now + exp_seconds))
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

# Get Domain
domain=$(cat /etc/xray/domain 2>/dev/null)
if [[ -z "$domain" ]]; then
    domain=$(curl -s https://ipinfo.io/ip/)
fi

# Get Ports
ssh_ws=$(grep -w "SSH Websocket" /root/log-install.txt | cut -d: -f2 | awk '{print $1}')
ssh_ssl=$(grep -w "SSH SSL Websocket" /root/log-install.txt | cut -d: -f2 | awk '{print $1}')
ssl_port=$(grep -w "Stunnel5" /root/log-install.txt | cut -d: -f2 | awk '{print $1}')

# JSON Response
cat <<EOF
{
  "status": "success",
  "message": "Account created successfully",
  "data": {
    "username": "$user",
    "password": "$pass",
    "domain": "$domain",
    "expired": "$exp_date",
    "ip_limit": "$iplimit",
    "quota": "$quota",
    "ssh_ws_port": "$ssh_ws",
    "ssh_ssl_port": "$ssh_ssl",
    "ssl_port": "$ssl_port"
  }
}
EOF
