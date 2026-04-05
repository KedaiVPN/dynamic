#!/bin/bash
clear && printf '\033[3J'

# Warn the user and ask for credentials
echo -e "\E[44;1;39m      RESTORE DATA MIGRASI VPN/SSH      \E[0m"
echo -e "Script ini akan mengunduh file data migrasi (.txt) dari Telegram Bot"
echo -e "dan memasukkan semua akun ke VPS ini (menimpa jika sudah ada)."
echo ""
read -p "Masukkan Bot Token Telegram : " BOT_TOKEN
if [[ -z "$BOT_TOKEN" ]]; then
    echo "Bot Token tidak boleh kosong!"
    exit 1
fi

read -p "Masukkan File ID Telegram   : " FILE_ID
if [[ -z "$FILE_ID" ]]; then
    echo "File ID tidak boleh kosong!"
    exit 1
fi

echo -e "\n[ INFO ] Menghubungi API Telegram..."
FILE_INFO=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getFile?file_id=${FILE_ID}")
API_OK=$(echo "$FILE_INFO" | grep -o '"ok":true')

if [[ -z "$API_OK" ]]; then
    echo "[ ERROR ] Gagal mendapatkan info file. Pastikan Token dan File ID valid."
    echo "Respons Telegram: $FILE_INFO"
    exit 1
fi

FILE_PATH=$(echo "$FILE_INFO" | grep -o '"file_path":"[^"]*' | cut -d'"' -f4)
if [[ -z "$FILE_PATH" ]]; then
    echo "[ ERROR ] Gagal mendapatkan file_path dari API."
    exit 1
fi

echo "[ INFO ] Mengunduh file migrasi..."
FILE_URL="https://api.telegram.org/file/bot${BOT_TOKEN}/${FILE_PATH}"
TMP_FILE="/tmp/migrasi.txt"
curl -sL "$FILE_URL" -o "$TMP_FILE"

if [[ ! -s "$TMP_FILE" ]]; then
    echo "[ ERROR ] File unduhan kosong atau gagal diunduh."
    exit 1
fi

echo "[ INFO ] File berhasil diunduh. Memulai proses restore..."

# Fungsi Helper untuk timestamp
get_timestamp() {
    local date_str="$1"
    local clean_date=$(echo "$date_str" | tr -d ',')
    # Set expiration to 23:59:59 of that day to ensure full day quota
    local ts=$(date -d "$clean_date 23:59:59" +%s 2>/dev/null)

    # Fallback if parsing fails (dirty data), return 0 so it gets marked expired safely
    # instead of writing blank values to DB which breaks xp.sh
    if [[ -z "$ts" ]]; then
        echo "0"
    else
        echo "$ts"
    fi
}

get_yyyy_mm_dd() {
    local date_str="$1"
    local clean_date=$(echo "$date_str" | tr -d ',')
    date -d "$clean_date" +"%Y-%m-%d" 2>/dev/null
}

# --- PROSES SSH ---
echo "[ INFO ] Memproses data SSH..."
awk '/^Ssh$/,/^$/' "$TMP_FILE" | grep -v "^Ssh$" | grep -v "^Username" | while read -r line; do
    if [[ -z "$line" ]]; then continue; fi

    # Format: Username Password(hash) ip_limit exp_month exp_day, exp_year
    # Example: handunSSH935 $6$xxx 1 Apr 09, 2026

    user=$(echo "$line" | awk '{print $1}')
    pass_hash=$(echo "$line" | awk '{print $2}')
    ip_limit=$(echo "$line" | awk '{print $3}')
    exp_str=$(echo "$line" | awk '{print $4, $5, $6}')

    if [[ -z "$user" || -z "$pass_hash" || -z "$exp_str" ]]; then
        continue
    fi

    exp_date=$(get_yyyy_mm_dd "$exp_str")
    exp_ts=$(get_timestamp "$exp_str")

    # Cek apakah user sudah ada
    if id "$user" &>/dev/null; then
        echo "  - Update SSH user: $user"
        usermod -p "$pass_hash" -e "$exp_date" "$user"
    else
        echo "  - Create SSH user: $user"
        useradd -e "$exp_date" -s /bin/false -M -p "$pass_hash" "$user"
    fi

    # Update IP Limit
    limit_file="/etc/ssh/limit-user.conf"
    mkdir -p /etc/ssh
    if [ -f "$limit_file" ]; then
        awk -v u="$user" '$1!=u' "$limit_file" > "${limit_file}.tmp" && mv "${limit_file}.tmp" "$limit_file"
    fi
    echo "$user $ip_limit" >> "$limit_file"

    # Update Expired DB
    if [ -f "/etc/expired-users.db" ]; then
        awk -v u="$user" -v p="ssh" '$1!=u || $2!=p' /etc/expired-users.db > /tmp/exp.tmp && mv /tmp/exp.tmp /etc/expired-users.db
    fi
    echo "$user ssh $exp_ts" >> /etc/expired-users.db
done

# --- PROSES VMESS ---
echo "[ INFO ] Memproses data Vmess..."
awk '/^vmess$/,/^$/' "$TMP_FILE" | grep -v "^vmess$" | grep -v "^Username" | while read -r line; do
    if [[ -z "$line" ]]; then continue; fi

    # Format: Username UUID quota exp
    # Example: BulukudanilVM331 e4d61a3a-fa53-4029-a833-06180c95bafc 200 GB 2026-03-20

    user=$(echo "$line" | awk '{print $1}')
    uuid=$(echo "$line" | awk '{print $2}')
    quota_val=$(echo "$line" | awk '{print $3}')
    exp_str=$(echo "$line" | awk '{print $5}')

    if [[ -z "$user" || -z "$uuid" || -z "$exp_str" ]]; then
        continue
    fi

    exp_date=$(get_yyyy_mm_dd "$exp_str")
    exp_ts=$(get_timestamp "$exp_str")

    echo "  - Restore Vmess user: $user"

    # Remove existing
    sed -i "/^#vms $user /,/^},{/d" /etc/xray/config.json
    sed -i "/^#vmsg $user /,/^},{/d" /etc/xray/config.json
    sed -i "/^### $user /,/^},{/d" /etc/xray/config.json

    # Add new
    sed -i '/#vmess$/a\#vms '"$user $exp_date"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#vmessworry$/a\### '"$user $exp_date"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#vmesskuota$/a\### '"$user $exp_date"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#vmessgrpc$/a\#vmsg '"$user $exp_date"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json

    # Limit DB
    limit_dir="/etc/xray/limit"
    mkdir -p "$limit_dir"
    limit_file="${limit_dir}/vmess"
    lock_file="${limit_dir}/lock-vmess"
    touch "$limit_file" "$lock_file"
    sed -i "/^$user /d" "$limit_file" "$lock_file"
    echo "$user $uuid $exp_date $quota_val 0" >> "$limit_file"

    # Update Expired DB
    if [ -f "/etc/expired-users.db" ]; then
        awk -v u="$user" -v p="vmess" '$1!=u || $2!=p' /etc/expired-users.db > /tmp/exp.tmp && mv /tmp/exp.tmp /etc/expired-users.db
    fi
    echo "$user vmess $exp_ts" >> /etc/expired-users.db
done

# --- PROSES VLESS ---
echo "[ INFO ] Memproses data Vless..."
awk '/^vless$/,/^$/' "$TMP_FILE" | grep -v "^vless$" | grep -v "^Username" | while read -r line; do
    if [[ -z "$line" ]]; then continue; fi

    user=$(echo "$line" | awk '{print $1}')
    uuid=$(echo "$line" | awk '{print $2}')
    quota_val=$(echo "$line" | awk '{print $3}')
    exp_str=$(echo "$line" | awk '{print $5}')

    if [[ -z "$user" || -z "$uuid" || -z "$exp_str" ]]; then
        continue
    fi

    exp_date=$(get_yyyy_mm_dd "$exp_str")
    exp_ts=$(get_timestamp "$exp_str")

    echo "  - Restore Vless user: $user"

    # Remove existing
    sed -i "/^#vls $user /,/^},{/d" /etc/xray/config.json
    sed -i "/^#vlsg $user /,/^},{/d" /etc/xray/config.json

    # Add new
    sed -i '/#vless$/a\#vls '"$user $exp_date"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#vlessgrpc$/a\#vlsg '"$user $exp_date"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json

    # Limit DB
    limit_dir="/etc/xray/limit"
    mkdir -p "$limit_dir"
    limit_file="${limit_dir}/vless"
    lock_file="${limit_dir}/lock-vless"
    touch "$limit_file" "$lock_file"
    sed -i "/^$user /d" "$limit_file" "$lock_file"
    echo "$user $uuid $exp_date $quota_val 0" >> "$limit_file"

    # Update Expired DB
    if [ -f "/etc/expired-users.db" ]; then
        awk -v u="$user" -v p="vless" '$1!=u || $2!=p' /etc/expired-users.db > /tmp/exp.tmp && mv /tmp/exp.tmp /etc/expired-users.db
    fi
    echo "$user vless $exp_ts" >> /etc/expired-users.db
done

# --- PROSES TROJAN ---
echo "[ INFO ] Memproses data Trojan..."
awk '/^trojan$/,/^$/' "$TMP_FILE" | grep -v "^trojan$" | grep -v "^Username" | while read -r line; do
    if [[ -z "$line" ]]; then continue; fi

    user=$(echo "$line" | awk '{print $1}')
    uuid=$(echo "$line" | awk '{print $2}')
    quota_val=$(echo "$line" | awk '{print $3}')
    exp_str=$(echo "$line" | awk '{print $5}')

    if [[ -z "$user" || -z "$uuid" || -z "$exp_str" ]]; then
        continue
    fi

    exp_date=$(get_yyyy_mm_dd "$exp_str")
    exp_ts=$(get_timestamp "$exp_str")

    echo "  - Restore Trojan user: $user"

    # Remove existing
    sed -i "/^#tr $user /,/^},{/d" /etc/xray/config.json
    sed -i "/^#trg $user /,/^},{/d" /etc/xray/config.json

    # Add new
    sed -i '/#trojanws$/a\#tr '"$user $exp_date"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#trojangrpc$/a\#trg '"$user $exp_date"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json

    # Limit DB
    limit_dir="/etc/xray/limit"
    mkdir -p "$limit_dir"
    limit_file="${limit_dir}/trojan"
    lock_file="${limit_dir}/lock-trojan"
    touch "$limit_file" "$lock_file"
    sed -i "/^$user /d" "$limit_file" "$lock_file"
    echo "$user $uuid $exp_date $quota_val 0" >> "$limit_file"

    # Update Expired DB
    if [ -f "/etc/expired-users.db" ]; then
        awk -v u="$user" -v p="trojan" '$1!=u || $2!=p' /etc/expired-users.db > /tmp/exp.tmp && mv /tmp/exp.tmp /etc/expired-users.db
    fi
    echo "$user trojan $exp_ts" >> /etc/expired-users.db
done

# Clean up & Restart services
rm -f "$TMP_FILE"
echo "[ INFO ] Menyimpan konfigurasi dan merestart service..."
systemctl restart ssh > /dev/null 2>&1
systemctl restart xray > /dev/null 2>&1
service cron restart > /dev/null 2>&1

echo -e "\033[0;32m[ OK ] Proses restore migrasi selesai!\033[0m"
