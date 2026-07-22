#!/bin/bash
# API Module: SSH Create
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

# Apply Format: UserSSH(3 Random Chars)
rand_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)
user="${raw_user}SSH${rand_suffix}"

# Check if user exists
if id "$user" >/dev/null 2>&1; then
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
