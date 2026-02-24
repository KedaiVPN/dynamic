#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V1.0
# Auther  : NevermoreSSH
# (C) Copyright 2022
# =========================================
clear
read -rp "Domain/Host: " -e host
if [ -z "$host" ]; then
    echo "Domain cannot be empty!"
    exit 1
fi

# Update variable config
echo "IP=$host" > /var/lib/scrz-prem/ipvps.conf
echo "IP=$host" > /var/lib/premium-script/ipvps.conf # Maintain compatibility

# Update persistent domain file for Xray
mkdir -p /etc/xray
echo "$host" > /etc/xray/domain

# Update legacy /root/domain for scripts that might need it
echo "$host" > /root/domain

# Update acme.sh certificate if domain changed
echo "Renewing Certificate..."
systemctl stop nginx
systemctl stop xray
/root/.acme.sh/acme.sh --issue -d "$host" --standalone --keylength ec-256 --force
/root/.acme.sh/acme.sh --install-cert -d "$host" --ecc --fullchain-file /etc/xray/xray.crt --key-file /etc/xray/xray.key --force
systemctl start nginx
systemctl start xray

echo ""
echo "Domain updated to: $host"
echo "Certificate renewed."
