#!/bin/bash
# API Module: SlowDNS Trial
# Args: none

# Load and verify SlowDNS configuration
if [[ -r /usr/lib/slowdns-config.sh ]]; then
    # shellcheck disable=SC1091
    source /usr/lib/slowdns-config.sh
    slowdns_load_config
elif [[ -r "$(dirname "$0")/../slowdns-config.sh" ]]; then
    # shellcheck disable=SC1091
    source "$(dirname "$0")/../slowdns-config.sh"
    slowdns_load_config
else
    echo '{"status": "error", "message": "SlowDNS configuration not found on server"}'
    exit 1
fi

if ! slowdns_is_active; then
    echo '{"status": "error", "message": "SlowDNS service is not active on this server"}'
    exit 1
fi

rand_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)
user="trialDNS${rand_suffix}"
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

dns_addr="$SLOWDNS_RESOLVER"
if [[ ! "$dns_addr" =~ ^[0-9]+(\.[0-9]+){3}:53$ ]]; then
    if [[ -n "${SLOWDNS_UDP_ADDR:-}" && "$SLOWDNS_UDP_ADDR" =~ ^[0-9]+(\.[0-9]+){3}:53$ ]]; then
        dns_addr="$SLOWDNS_UDP_ADDR"
    fi
fi

cat <<EOF
{
  "status": "success",
  "message": "Trial account created",
  "data": {
    "username": "$user",
    "password": "$pass",
    "domain": "$SLOWDNS_DOMAIN",
    "ns_domain": "$SLOWDNS_NS_DOMAIN",
    "pubkey": "$SLOWDNS_PUBKEY",
    "dns": "$dns_addr",
    "expired": "30 Minutes",
    "ip_limit": "1",
    "quota": "0"
  }
}
EOF
