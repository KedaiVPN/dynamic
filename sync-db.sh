#!/bin/bash

# ==========================================
# Auto Sync / Rebuild Database Expired
# Digunakan setelah restore atau ketika db hilang
# ==========================================

export RED='\033[0;31m'
export GREEN='\033[0;32m'
export NC='\033[0m'

EXP_DB="/etc/expired-users.db"

if [ ! -f "$EXP_DB" ]; then
    touch "$EXP_DB"
fi

echo -e "[ ${GREEN}INFO${NC} ] Memulai sinkronisasi database expired-users.db..."

# --- 1. Sinkronisasi SSH ---
# Membaca daftar user SSH dari /etc/passwd (UID >= 1000 dan shell /bin/false)
awk -F':' '{if ($3 >= 1000 && $7 == "/bin/false") print $1}' /etc/passwd | while read user; do
    # Cek expiry via chage
    exp=$(LANG=C chage -l "$user" 2>/dev/null | grep "Account expires" | awk -F': ' '{print $2}')
    if [ "$exp" != "never" ] && [ -n "$exp" ]; then
        exp_ts=$(date -d "$exp" +%s 2>/dev/null)
        if [ -n "$exp_ts" ]; then
            # Jika user belum ada di DB, tambahkan
            if ! grep -q "^$user ssh " "$EXP_DB"; then
                echo "$user ssh $exp_ts" >> "$EXP_DB"
                echo -e "  [+] Resynced SSH user: $user (Exp: $exp_ts)"
            fi
        fi
    fi
done

# --- 2. Sinkronisasi XRAY (Vmess, Vless, Trojan) ---
protocols=("vmess" "vless" "trojan")

for proto in "${protocols[@]}"; do
    limit_dir="/etc/xray/limit"
    if [ -d "$limit_dir" ] && [ -f "$limit_dir/$proto" ]; then
        cat "$limit_dir/$proto" | while read -r line; do
            user=$(echo "$line" | awk '{print $1}')
            exp_ts=$(echo "$line" | awk '{print $3}' | tr -d '\r\n')

            if [ -n "$user" ] && [ -n "$exp_ts" ]; then
                if ! grep -q "^$user $proto " "$EXP_DB"; then
                    echo "$user $proto $exp_ts" >> "$EXP_DB"
                    echo -e "  [+] Resynced $proto user: $user (Exp: $exp_ts)"
                fi
            fi
        done
    fi
done

echo -e "[ ${GREEN}OK${NC} ] Sinkronisasi selesai!"
