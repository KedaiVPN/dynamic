#!/bin/bash
# =========================================
# Smart Ghost Account Cleanup & Recovery Script
# Created by Jules
# Identifies untracked accounts, syncs active ones, and deletes/trashes expired ones
# =========================================

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export NC='\033[0m'

EXP_DB="/etc/expired-users.db"
TRASH_DB="/etc/expired-users-trash.db"

if [ ! -f "$EXP_DB" ]; then
    touch "$EXP_DB"
fi
if [ ! -f "$TRASH_DB" ]; then
    touch "$TRASH_DB"
fi

now_timestamp=$(date +%s)
echo -e "[ ${GREEN}INFO${NC} ] Memulai Smart Ghost Cleanup..."
restart_xray=0

clean_xray_ghosts() {
    local protocol=$1
    local prefix=$2

    grep -E "^ *${prefix} " /etc/xray/config.json 2>/dev/null | while read -r line; do
        user=$(echo "$line" | awk '{print $2}')
        exp_date=$(echo "$line" | awk '{print $3}')

        # Cek apakah user ada di database utama
        if ! grep -q "^$user $protocol " "$EXP_DB"; then
            # Ambil timestamp expired asli dari config, tambahkan 23:59:59 untuk akurasi full 1 hari
            exp_ts=$(date -d "$exp_date 23:59:59" +%s 2>/dev/null)

            # Jika timestamp gagal di-parse (format rusak), kita anggap expired langsung
            if [[ -z "$exp_ts" ]]; then
                exp_ts=0
            fi

            if [[ "$exp_ts" -gt "$now_timestamp" ]]; then
                echo -e "${YELLOW}Menyelamatkan akun aktif yang tidak terlacak: $user ($protocol)${NC}"
                echo "$user $protocol $exp_ts" >> "$EXP_DB"
            else
                echo -e "${RED}Menghapus akun hantu kedaluwarsa: $user ($protocol)${NC}"

                # Ekstrak UUID/Password untuk keperluan TRASH
                if [[ "$protocol" == "vmess" || "$protocol" == "vless" ]]; then
                    uuid=$(grep -A 1 "${prefix} $user " /etc/xray/config.json | grep "id" | cut -d '"' -f 4 | head -n 1 | tr -d '\n\r ')
                else
                    uuid=$(grep -A 1 "${prefix} $user " /etc/xray/config.json | grep "password" | cut -d '"' -f 4 | head -n 1 | tr -d '\n\r ')
                fi
                if [ -z "$uuid" ]; then uuid="unknown"; fi

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

                # Masukkan ke TRASH
                if ! grep -q "^$user $protocol " "$TRASH_DB"; then
                    echo "$user $protocol $now_timestamp $uuid" >> "$TRASH_DB"
                fi

                # Tandai bahwa Xray perlu direstart
                echo "1" > /tmp/xray_needs_restart
            fi
        fi
    done
}

# Bersihkan & Sinkronkan akun Xray
rm -f /tmp/xray_needs_restart
clean_xray_ghosts "vmess" "#vms"
clean_xray_ghosts "vless" "#vls"
clean_xray_ghosts "trojan" "#tr"
clean_xray_ghosts "ssws" "#ssw"

if [ -f "/tmp/xray_needs_restart" ]; then
    systemctl restart xray >/dev/null 2>&1
    rm -f /tmp/xray_needs_restart
fi

# Bersihkan & Sinkronkan akun SSH
awk -F: '$3 >= 1000 && $1 != "nobody" && $7 == "/bin/false" {print $1}' /etc/passwd | while read -r user; do
    if ! grep -q "^$user ssh " "$EXP_DB"; then

        # Cek tanggal expired asli SSH
        exp_date=$(chage -l "$user" 2>/dev/null | grep "Account expires" | awk -F': ' '{print $2}')
        if [[ -n "$exp_date" && "$exp_date" != "never" ]]; then
            clean_date=$(echo "$exp_date" | tr -d ',')
            exp_ts=$(date -d "$clean_date 23:59:59" +%s 2>/dev/null)
            if [[ -z "$exp_ts" ]]; then exp_ts=0; fi

            if [[ "$exp_ts" -gt "$now_timestamp" ]]; then
                echo -e "${YELLOW}Menyelamatkan akun aktif SSH yang tidak terlacak: $user${NC}"
                echo "$user ssh $exp_ts" >> "$EXP_DB"
            else
                echo -e "${RED}Menghapus akun hantu kedaluwarsa SSH: $user${NC}"
                pass="merged-hashed"
                userdel --force "$user" 2>/dev/null
                if [ -f "/etc/ssh/limit-user.conf" ]; then
                    sed -i "/^$user /d" /etc/ssh/limit-user.conf
                fi

                if ! grep -q "^$user ssh " "$TRASH_DB"; then
                    echo "$user ssh $now_timestamp $pass" >> "$TRASH_DB"
                fi
            fi
        fi
    fi
done

echo -e "[ ${GREEN}INFO${NC} ] Proses Smart Cleanup selesai."
