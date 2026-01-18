#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V1.0
# Auther  : NevermoreSSH
# (C) Copyright 2022
# =========================================

# // Export Color & Information
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export LIGHT='\033[0;37m'
export NC='\033[0m'

# // Database Expired Users
EXP_DB="/etc/expired-users.db"

if [ ! -f "$EXP_DB" ]; then
    echo "Database expired users not found!"
    exit 1
fi

now_timestamp=$(date +%s)

# Read database line by line
# Format: username type timestamp
while read -r line; do
    # Skip empty lines
    if [[ -z "$line" ]]; then
        continue
    fi

    user=$(echo "$line" | awk '{print $1}')
    type=$(echo "$line" | awk '{print $2}')
    exp_timestamp=$(echo "$line" | awk '{print $3}')

    if [[ "$now_timestamp" -ge "$exp_timestamp" ]]; then
        echo -e "${RED}Deleting expired account: $user ($type)${NC}"

        case $type in
            ssh)
                userdel --force "$user"
                # Remove from limit-user.conf if exists
                if [ -f "/etc/ssh/limit-user.conf" ]; then
                    sed -i "/^$user /d" /etc/ssh/limit-user.conf
                fi
                ;;
            vmess)
                sed -i "/^#vms $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^#vmsg $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^### $user /,/^ *},{/d" /etc/xray/config.json
                rm -f /etc/xray/$user-tls.json /etc/xray/$user-none.json
                sed -i "/^$user /d" /etc/xray/limit/vmess /etc/xray/limit/lock-vmess
                ;;
            vless)
                sed -i "/^#vls $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^#vlsg $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^$user /d" /etc/xray/limit/vless /etc/xray/limit/lock-vless
                ;;
            trojan)
                sed -i "/^#tr $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^#trg $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^$user /d" /etc/xray/limit/trojan /etc/xray/limit/lock-trojan
                ;;
            ssws)
                sed -i "/^#ssw $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^#sswg $user /,/^ *},{/d" /etc/xray/config.json
                ;;
        esac

        # Remove from database
        grep -v "^$user $type $exp_timestamp" "$EXP_DB" > "${EXP_DB}.tmp" && mv "${EXP_DB}.tmp" "$EXP_DB"

        # Restart Xray service if needed (only for Xray types)
        if [[ "$type" != "ssh" ]]; then
             systemctl restart xray
        fi
    fi
done < "$EXP_DB"
