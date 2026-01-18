#!/bin/bash
# Script untuk mengecek daftar user yang akan expired dengan format tanggal & jam presisi
# Created by Jules

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

EXP_DB="/etc/expired-users.db"

clear
echo -e "${BLUE}=========================================================${NC}"
echo -e "${YELLOW}          DAFTAR USER AKAN EXPIRED (PRESISI JAM)         ${NC}"
echo -e "${BLUE}=========================================================${NC}"

if [ ! -f "$EXP_DB" ]; then
    echo -e "${RED}Database expired-users.db tidak ditemukan!${NC}"
    echo -e "Pastikan fitur auto-delete presisi sudah diupdate."
    exit 1
fi

# Header Tabel
printf "${CYAN}%-15s %-10s %-25s${NC}\n" "USERNAME" "TIPE" "WAKTU EXPIRED (WIB)"
echo -e "---------------------------------------------------------"

# Baca database
while read -r line; do
    if [[ -z "$line" ]]; then continue; fi

    user=$(echo "$line" | awk '{print $1}')
    type=$(echo "$line" | awk '{print $2}')
    exp_timestamp=$(echo "$line" | awk '{print $3}')

    # Konversi timestamp ke format tanggal jam
    # Pastikan timezone sudah Asia/Jakarta di sistem, atau paksa di date
    readable_date=$(date -d @"$exp_timestamp" "+%d-%m-%Y %H:%M:%S")

    printf "%-15s %-10s %-25s\n" "$user" "$type" "$readable_date"

done < "$EXP_DB"

echo -e "---------------------------------------------------------"
echo -e "Total User: $(wc -l < $EXP_DB)"
echo -e ""
