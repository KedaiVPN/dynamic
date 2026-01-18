#!/bin/bash
# Script Auto Update untuk Fitur Timezone & Auto-Delete Presisi
# Created by Jules

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "[ ${GREEN}INFO${NC} ] Memulai Update..."

# 1. Update Timezone ke Asia/Jakarta
echo -e "[ ${GREEN}INFO${NC} ] Mengatur Timezone ke Asia/Jakarta..."
timedatectl set-timezone Asia/Jakarta
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# 2. Download Script Baru
# Pastikan URL ini sesuai dengan raw repository Anda
REPO="https://raw.githubusercontent.com/KedaiVPN/dynamic/main"

echo -e "[ ${GREEN}INFO${NC} ] Mendownload script terbaru..."
wget -q -O /usr/bin/add-ws "${REPO}/add-ws.sh" && chmod +x /usr/bin/add-ws
wget -q -O /usr/bin/add-vless "${REPO}/add-vless.sh" && chmod +x /usr/bin/add-vless
wget -q -O /usr/bin/add-tr "${REPO}/add-tr.sh" && chmod +x /usr/bin/add-tr
wget -q -O /usr/bin/add-ssws "${REPO}/add-ssws.sh" && chmod +x /usr/bin/add-ssws
wget -q -O /usr/bin/usernew "${REPO}/usernew.sh" && chmod +x /usr/bin/usernew
wget -q -O /usr/bin/xp "${REPO}/xp.sh" && chmod +x /usr/bin/xp
wget -q -O /usr/bin/cek-expired "${REPO}/cek-expired.sh" && chmod +x /usr/bin/cek-expired

# 3. Buat Database Expired & Trash
echo -e "[ ${GREEN}INFO${NC} ] Membuat database expired & trash users..."
if [ ! -f /etc/expired-users.db ]; then
    touch /etc/expired-users.db
    chmod 644 /etc/expired-users.db
    echo "Database expired-users.db dibuat."
fi

if [ ! -f /etc/expired-users-trash.db ]; then
    touch /etc/expired-users-trash.db
    chmod 644 /etc/expired-users-trash.db
    echo "Database expired-users-trash.db dibuat."
fi

# 4. Update Cron Job
echo -e "[ ${GREEN}INFO${NC} ] Memperbarui Cron Job..."
# Hapus cron xp lama jika ada (yang harian atau duplikat)
sed -i "/root xp/d" /etc/crontab
# Tambahkan cron xp baru (tiap 10 menit)
echo "*/10 * * * * root xp" >> /etc/crontab
# Restart cron
service cron restart

echo -e "[ ${GREEN}INFO${NC} ] Update Selesai!"
echo -e "[ ${GREEN}INFO${NC} ] Fitur Auto-Delete presisi (10 menit) sudah aktif."
echo -e "[ ${GREEN}INFO${NC} ] Timezone server sekarang: $(date)"
