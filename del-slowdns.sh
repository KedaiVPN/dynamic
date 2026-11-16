#!/bin/bash
# =========================================
# Quick Setup | Script Komplit Untuk VPS
# Edition : Stable Edition V1.0
# Auther  : Adit Ardiansyah
# (C) Copyright 2021-2026 By KedaiVPN
# =========================================
clear && printf '\033[3J'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export LIGHT='\033[0;37m'
export NC='\033[0m'
export EROR="[${RED} EROR ${NC}]"

# Root Checking
if [ "${EUID}" -ne 0 ]; then
    echo -e "${EROR} Please Run This Script As Root User !"
    exit 1
fi

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m          DELETE SLOWDNS ACCOUNT          \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -p "Username SlowDNS to Delete : " Pengguna

if [[ -z "$Pengguna" ]]; then
    echo -e "${EROR} Username tidak boleh kosong!"
    read -n 1 -s -r -p "Press any key to back on menu"
    menu
    exit 1
fi

found=0

# Delete SSH User if exists
if getent passwd "$Pengguna" > /dev/null 2>&1; then
    userdel -f "$Pengguna" > /dev/null 2>&1
    sed -i "/^$Pengguna ssh /d" /etc/expired-users.db 2>/dev/null
    sed -i "/^$Pengguna /d" /etc/ssh/limit-user.conf 2>/dev/null
    found=1
fi

# Delete Xray VMess & VLess User if exists
if [ -f /etc/xray/config.json ]; then
    if grep -q "$Pengguna" /etc/xray/config.json 2>/dev/null; then
        sed -i "/^ *#vms $Pengguna /,/^ *},{/d" /etc/xray/config.json
        sed -i "/^ *#vmsg $Pengguna /,/^ *},{/d" /etc/xray/config.json
        sed -i "/^ *#vls $Pengguna /,/^ *},{/d" /etc/xray/config.json
        sed -i "/^ *#vlsg $Pengguna /,/^ *},{/d" /etc/xray/config.json
        sed -i "/^$Pengguna vmess /d" /etc/expired-users.db 2>/dev/null
        sed -i "/^$Pengguna vless /d" /etc/expired-users.db 2>/dev/null
        sed -i "/^$Pengguna /d" /etc/xray/limit/vmess 2>/dev/null
        sed -i "/^$Pengguna /d" /etc/xray/limit/vless 2>/dev/null
        systemctl restart xray >/dev/null 2>&1 || true
        found=1
    fi
fi

if [[ $found -eq 1 ]]; then
    echo -e "User SlowDNS '$Pengguna' (SSH & V2Ray) successfully removed."
else
    echo -e "Failure: User '$Pengguna' not found."
fi

read -n 1 -s -r -p "Press any key to back on menu"
menu
