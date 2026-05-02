#!/bin/bash

# // License Checking
if [ -f /usr/local/bin/cek-lisensi ]; then
    /usr/local/bin/cek-lisensi --check-only || exit 1
fi

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

# // Databases
EXP_DB="/etc/expired-users.db"
TRASH_DB="/etc/expired-users-trash.db"

if [ ! -f "$EXP_DB" ]; then
    echo "Database expired users not found!"
    exit 1
fi

if [ ! -f "$TRASH_DB" ]; then
    touch "$TRASH_DB"
fi

now_timestamp=$(date +%s)

# ==========================================
# 1. PROCESS ACTIVE EXPIRATIONS (Move to Trash)
# ==========================================
tmp_file=$(mktemp)
cp "$EXP_DB" "$tmp_file"
while read -r line; do
    if [[ -z "$line" ]]; then continue; fi

    user=$(echo "$line" | awk '{print $1}')
    type=$(echo "$line" | awk '{print $2}')
    exp_timestamp=$(echo "$line" | awk '{print $3}' | tr -d '\r\n')

    # Ensure exp_timestamp is a valid integer before comparison
    if ! [[ "$exp_timestamp" =~ ^[0-9]+$ ]]; then continue; fi

    if [[ "$now_timestamp" -ge "$exp_timestamp" ]]; then
        echo -e "${RED}Moving expired account to trash: $user ($type)${NC}"

        # Extract credentials and save to trash before deletion
        # Format Trash: username type deleted_timestamp password/uuid

        case $type in
            ssh)
                # Get password from shadow (requires root) -> Actually we can't easily get cleartext password.
                # User asked to save "username, password, uuid".
                # For SSH, we can't recover the password if hashed in /etc/shadow unless we saved it somewhere else during creation.
                # However, usually we can't restore 'password' unless we reset it.
                # Assumption: The user creates account via script which sets password. But we don't store cleartext password in db.
                # WORKAROUND: We will save "locked" status. Or if we assume `usernew.sh` saved it? No.
                # Let's save a placeholder or maybe we just lock the user?
                # The prompt says: "username, password, and uuid move to new file".
                # Since we don't have the password, we will save "UNKNOWN" or just skip it.
                # BUT, wait. If we DELETE the user `userdel`, we lose the password hash.
                # If we restore, we need to ask for a NEW password or we can't restore the old one.
                # Let's stick to the prompt: "restore... will ask for limit ip... limit bandwidth... expiry". It implies recreating.
                # So we probably need to ask for a NEW password during restore for SSH.

                pass="merged-hashed" # Placeholder
                userdel --force "$user"
                if [ -f "/etc/ssh/limit-user.conf" ]; then
                    sed -i "/^$user /d" /etc/ssh/limit-user.conf
                fi
                ;;
            vmess)
                # Extract UUID from config before deleting
                # Config format: "id": "uuid", ... "email": "user"
                # We need to find the block for this user and extract ID
                uuid=$(grep -A 1 "#vms $user " /etc/xray/config.json | grep "id" | cut -d '"' -f 4 | head -n 1 | tr -d '\n\r ')
                if [ -z "$uuid" ]; then uuid="unknown"; fi

                sed -i "/^ *#vms $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^ *#vmsg $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^ *### $user /,/^ *},{/d" /etc/xray/config.json
                rm -f /etc/xray/$user-tls.json /etc/xray/$user-none.json
                sed -i "/^$user /d" /etc/xray/limit/vmess /etc/xray/limit/lock-vmess
                pass="$uuid"
                ;;
            vless)
                uuid=$(grep -A 1 "#vls $user " /etc/xray/config.json | grep "id" | cut -d '"' -f 4 | head -n 1 | tr -d '\n\r ')
                if [ -z "$uuid" ]; then uuid="unknown"; fi

                sed -i "/^ *#vls $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^ *#vlsg $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^$user /d" /etc/xray/limit/vless /etc/xray/limit/lock-vless
                pass="$uuid"
                ;;
            trojan)
                uuid=$(grep -A 1 "#tr $user " /etc/xray/config.json | grep "password" | cut -d '"' -f 4 | head -n 1 | tr -d '\n\r ')
                if [ -z "$uuid" ]; then uuid="unknown"; fi

                sed -i "/^ *#tr $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^ *#trg $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^$user /d" /etc/xray/limit/trojan /etc/xray/limit/lock-trojan
                pass="$uuid"
                ;;
            ssws)
                # Shadowsock format might be different
                uuid=$(grep -A 1 "#ssw $user " /etc/xray/config.json | grep "password" | cut -d '"' -f 4 | head -n 1 | tr -d '\n\r ')
                if [ -z "$uuid" ]; then uuid="unknown"; fi

                sed -i "/^ *#ssw $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^ *#sswg $user /,/^ *},{/d" /etc/xray/config.json
                pass="$uuid"
                ;;
        esac

        # Ensure pass only contains a single word and no spaces/newlines
        pass=$(echo "$pass" | tr -d '\n\r ')
        if [ -z "$pass" ]; then pass="unknown"; fi

        # Add to TRASH database (Check for duplicates first)
        # Format: username type deleted_timestamp credentials(uuid/pass)
        if ! grep -q "^$user $type" "$TRASH_DB"; then
            echo "$user $type $now_timestamp $pass" >> "$TRASH_DB"
        fi

        # Remove from ACTIVE database
        # Use sed -i for safer deletion of the specific line
        sed -i "/^$user $type /d" "$EXP_DB"

        # Restart Xray service if needed
        if [[ "$type" != "ssh" ]]; then
             systemctl restart xray
        fi
    fi
done < "$tmp_file"
rm -f "$tmp_file"

# ==========================================
# 2. PROCESS TRASH CLEANUP (> 3 Days)
# ==========================================
# 3 days in seconds = 3 * 24 * 3600 = 259200
TRASH_LIMIT=259200

if [ -f "$TRASH_DB" ]; then
    tmp_file=$(mktemp)
    cp "$TRASH_DB" "$tmp_file"
    while read -r line; do
        if [[ -z "$line" ]]; then continue; fi

        user=$(echo "$line" | awk '{print $1}')
        type=$(echo "$line" | awk '{print $2}')
        del_timestamp=$(echo "$line" | awk '{print $3}' | tr -d '\r')

        if [[ ! "$del_timestamp" =~ ^[0-9]+$ ]]; then continue; fi

        diff=$((now_timestamp - del_timestamp))

        if [[ "$diff" -ge "$TRASH_LIMIT" ]]; then
            echo -e "${RED}Permanently deleting from trash: $user ($type)${NC}"
            # Data is already removed from system, just remove from trash db
            grep -v "^$user $type $del_timestamp" "$TRASH_DB" > "${TRASH_DB}.tmp" && mv "${TRASH_DB}.tmp" "$TRASH_DB"
        fi
    done < "$tmp_file"
    rm -f "$tmp_file"
fi
