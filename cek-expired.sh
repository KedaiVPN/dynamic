#!/bin/bash

# // License Checking
if [ -f /usr/local/bin/cek-lisensi ]; then
    /usr/local/bin/cek-lisensi --check-only || exit 1
fi

# Script untuk mengecek daftar user expired (di Trash) dan melakukan Restore
# Created by Jules

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TRASH_DB="/etc/expired-users-trash.db"
EXP_DB="/etc/expired-users.db"

clear && printf '\033[3J'
echo -e "${BLUE}=========================================================${NC}"
echo -e "${YELLOW}      DAFTAR USER SUDAH EXPIRED (TRASH / BISA DI-RESTORE)      ${NC}"
echo -e "${BLUE}=========================================================${NC}"

if [ ! -f "$TRASH_DB" ] || [ ! -s "$TRASH_DB" ]; then
    echo -e "${RED}Tidak ada user yang expired (Trash kosong).${NC}"
    echo -e "${BLUE}=========================================================${NC}"
    read -n 1 -s -r -p "Tekan tombol apapun untuk kembali..."
    menu
    exit 0
fi

# Header Tabel
printf "${CYAN}%-15s %-10s %-25s${NC}\n" "USERNAME" "TIPE" "DIHAPUS PADA (WIB)"
echo -e "---------------------------------------------------------"

# Baca database
i=1
while read -r line; do
    if [[ -z "$line" ]]; then continue; fi

    user=$(echo "$line" | awk '{print $1}')
    type=$(echo "$line" | awk '{print $2}')
    del_timestamp=$(echo "$line" | awk '{print $3}')

    # Validasi apakah del_timestamp adalah angka (Unix timestamp)
    if ! [[ "$del_timestamp" =~ ^[0-9]+$ ]]; then
        continue # Skip baris yang corrupt/rusak
    fi

    readable_date=$(date -d @"$del_timestamp" "+%d-%m-%Y %H:%M:%S" 2>/dev/null)
    if [ $? -ne 0 ]; then
        continue # Skip jika konversi tanggal masih gagal
    fi

    printf "%-15s %-10s %-25s\n" "$user" "$type" "$readable_date"
    ((i++))
done < "$TRASH_DB"

echo -e "---------------------------------------------------------"
echo -e ""
echo -e "Ketik ${GREEN}username${NC} yang ingin di-restore dari daftar di atas."
echo -e "Atau ketik ${RED}x${NC} untuk keluar."
echo -e ""
read -p "Username: " restore_user

if [[ "$restore_user" == "x" ]]; then
    menu
    exit 0
fi

# Cari user di trash
data_line=$(grep "^$restore_user " "$TRASH_DB")

if [[ -z "$data_line" ]]; then
    echo -e "${RED}Username tidak ditemukan di Trash!${NC}"
    sleep 2
    cek-expired
    exit 1
fi

user=$(echo "$data_line" | awk '{print $1}')
type=$(echo "$data_line" | awk '{print $2}')
timestamp=$(echo "$data_line" | awk '{print $3}')
cred=$(echo "$data_line" | awk '{print $4}') # UUID atau Pass Placeholder

echo -e "\n${GREEN}Memproses Restore untuk user: $user ($type)${NC}"

# Input Data Baru
read -p "Masukkan Masa Aktif Baru (Hari): " masaaktif

if [[ "$type" == "ssh" ]]; then
    read -p "Masukkan Password Baru: " password
    read -p "Masukkan Limit IP (1-10): " limit_ip

    # Logic Re-create SSH
    useradd -e `date -d "$masaaktif days" +"%Y-%m-%d"` -s /bin/false -M $user
    echo -e "$password\n$password\n"|passwd $user &> /dev/null

    # Update Limit
    limit_file="/etc/ssh/limit-user.conf"
    if [ -f "$limit_file" ]; then
        awk -v user="$user" '$1!=user' "$limit_file" > "${limit_file}.tmp" && mv "${limit_file}.tmp" "$limit_file"
    fi
    echo "$user $limit_ip" >> "$limit_file"

elif [[ "$type" == "vmess" || "$type" == "vless" || "$type" == "trojan" || "$type" == "ssws" ]]; then
    read -p "Masukkan Limit Bandwidth (GB): " quota

    # Re-calculate Expiry
    exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
    uuid=$cred
    domain=$(cat /etc/xray/domain)

    # Re-inject to config.json based on type
    if [[ "$type" == "vmess" ]]; then
        sed -i '/#vmess$/a\#vms '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
        sed -i '/#vmessgrpc$/a\#vmsg '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
        # Tambahan logic limit file
        echo "$user $uuid $exp $quota 0" >> "/etc/xray/limit/vmess"

    elif [[ "$type" == "vless" ]]; then
        sed -i '/#vless$/a\#vls '"$user $exp"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
        sed -i '/#vlessgrpc$/a\#vlsg '"$user $exp"'\
},{"id": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
        echo "$user $uuid $exp $quota 0" >> "/etc/xray/limit/vless"

    elif [[ "$type" == "trojan" ]]; then
        sed -i '/#trojanws$/a\#tr '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
        sed -i '/#trojangrpc$/a\#trg '"$user $exp"'\
},{"password": "'""$uuid""'","email": "'""$user""'"' /etc/xray/config.json
        echo "$user $uuid $exp $quota 0" >> "/etc/xray/limit/trojan"

    elif [[ "$type" == "ssws" ]]; then
        cipher="aes-128-gcm"
        sed -i '/#ssws$/a\#ssw '"$user $exp"'\
},{"password": "'""$uuid""'","method": "'""$cipher""'","email": "'""$user""'"' /etc/xray/config.json
        sed -i '/#ssgrpc$/a\#sswg '"$user $exp"'\
},{"password": "'""$uuid""'","method": "'""$cipher""'","email": "'""$user""'"' /etc/xray/config.json
    fi

    systemctl restart xray
fi

# Update Databases
# 1. Add to active expiry db
now_timestamp=$(date +%s)
expiry_seconds=$((masaaktif * 86400))
expiry_timestamp=$((now_timestamp + expiry_seconds))
echo "$user $type $expiry_timestamp" >> "$EXP_DB"

# 2. Remove from trash
grep -v "^$user $type" "$TRASH_DB" > "${TRASH_DB}.tmp" || true
mv "${TRASH_DB}.tmp" "$TRASH_DB"

echo -e "\n${GREEN}User $user berhasil di-restore!${NC}"
echo -e "Masa aktif baru: $masaaktif hari"
read -n 1 -s -r -p "Tekan tombol apapun untuk kembali..."
menu
