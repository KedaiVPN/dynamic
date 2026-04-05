#!/bin/bash
# =========================================
# Ghost Account Cleanup Script
# Created by Jules
# Cleans up VPN/SSH accounts that exist in configs but are missing from expired-users.db
# =========================================

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export NC='\033[0m'

EXP_DB="/etc/expired-users.db"

if [ ! -f "$EXP_DB" ]; then
    touch "$EXP_DB"
fi

echo -e "[ ${GREEN}INFO${NC} ] Memulai pembersihan akun hantu (tidak terdaftar di database)..."
restart_xray=0

clean_xray_ghosts() {
    local protocol=$1
    local prefix=$2
    local lock_prefix=$3

    grep -E "^ *${prefix} " /etc/xray/config.json 2>/dev/null | while read -r line; do
        user=$(echo "$line" | awk '{print $2}')
        # Cek apakah user terdaftar di database utama
        if ! grep -q "^$user $protocol " "$EXP_DB"; then
            echo -e "${RED}Menghapus akun hantu $protocol: $user${NC}"

            # Hapus dari config.json sesuai dengan protocol
            if [[ "$protocol" == "vmess" ]]; then
                sed -i "/^ *#vms $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^ *#vmsg $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^ *### $user /,/^ *},{/d" /etc/xray/config.json
                rm -f /etc/xray/$user-tls.json /etc/xray/$user-none.json
                sed -i "/^$user /d" /etc/xray/limit/vmess /etc/xray/limit/lock-vmess 2>/dev/null
            elif [[ "$protocol" == "vless" ]]; then
                sed -i "/^ *#vls $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^ *#vlsg $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^$user /d" /etc/xray/limit/vless /etc/xray/limit/lock-vless 2>/dev/null
            elif [[ "$protocol" == "trojan" ]]; then
                sed -i "/^ *#tr $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^ *#trg $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^$user /d" /etc/xray/limit/trojan /etc/xray/limit/lock-trojan 2>/dev/null
            elif [[ "$protocol" == "ssws" ]]; then
                sed -i "/^ *#ssw $user /,/^ *},{/d" /etc/xray/config.json
                sed -i "/^ *#sswg $user /,/^ *},{/d" /etc/xray/config.json
            fi

            # Tandai bahwa Xray perlu direstart
            echo "1" > /tmp/xray_needs_restart
        fi
    done
}

# Bersihkan akun hantu Xray
rm -f /tmp/xray_needs_restart
clean_xray_ghosts "vmess" "#vms" "vmess"
clean_xray_ghosts "vless" "#vls" "vless"
clean_xray_ghosts "trojan" "#tr" "trojan"
clean_xray_ghosts "ssws" "#ssw" "ssws"

if [ -f "/tmp/xray_needs_restart" ]; then
    systemctl restart xray >/dev/null 2>&1
    rm -f /tmp/xray_needs_restart
fi

# Bersihkan akun hantu SSH
awk -F: '$3 >= 1000 && $1 != "nobody" && $7 == "/bin/false" {print $1}' /etc/passwd | while read -r user; do
    if ! grep -q "^$user ssh " "$EXP_DB"; then
        echo -e "${RED}Menghapus akun hantu SSH: $user${NC}"
        userdel --force "$user" 2>/dev/null
        if [ -f "/etc/ssh/limit-user.conf" ]; then
            sed -i "/^$user /d" /etc/ssh/limit-user.conf
        fi
    fi
done

echo -e "[ ${GREEN}INFO${NC} ] Pembersihan akun hantu selesai."
