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

# Install Dependencies (HAProxy)
#echo -e "[ ${GREEN}INFO${NC} ] Menginstall HAProxy..."
#apt install haproxy -y

echo -e "[ ${GREEN}INFO${NC} ] Mendownload script terbaru..."
#wget -q -O /usr/bin/add-host "${REPO}/add-host.sh" && chmod +x /usr/bin/add-host
#wget -q -O /usr/bin/ins-xray "${REPO}/ins-xray.sh" && chmod +x /usr/bin/ins-xray
#wget -q -O /usr/bin/add-ws "${REPO}/add-ws.sh" && chmod +x /usr/bin/add-ws
#wget -q -O /usr/bin/add-vless "${REPO}/add-vless.sh" && chmod +x /usr/bin/add-vless
#wget -q -O /usr/bin/add-tr "${REPO}/add-tr.sh" && chmod +x /usr/bin/add-tr
#wget -q -O /usr/bin/add-ssws "${REPO}/add-ssws.sh" && chmod +x /usr/bin/add-ssws
#wget -q -O /usr/bin/usernew "${REPO}/usernew.sh" && chmod +x /usr/bin/usernew
#wget -q -O /usr/bin/xp "${REPO}/xp.sh" && chmod +x /usr/bin/xp
#wget -q -O /usr/bin/cek-expired "${REPO}/cek-expired.sh" && chmod +x /usr/bin/cek-expired
#wget -q -O /usr/bin/menu "${REPO}/menu4.sh" && chmod +x /usr/bin/menu
#wget -q -O /usr/bin/menu-ssh "${REPO}/menu-ssh.sh" && chmod +x /usr/bin/menu-ssh
#wget -q -O /usr/bin/install-api "${REPO}/install-api.sh" && chmod +x /usr/bin/install-api && /usr/bin/install-api

# --- UPDATE API MODULES ONLY ---
echo -e "[ ${GREEN}INFO${NC} ] Updating API Modules (Xray Create Fix)..."
mkdir -p /usr/local/bin/api-modules

# Strategy: Download to temp -> Verify -> Replace
TMP_FILE="/tmp/api-xray-create.sh"
TARGET_FILE="/usr/local/bin/api-modules/api-xray-create.sh"

# Download with cache buster
wget -q -O "$TMP_FILE" "${REPO}/api-modules/api-xray-create.sh?v=$(date +%s)"

# Verification
if [ -f "$TMP_FILE" ] && grep -q "grpc_link" "$TMP_FILE"; then
    echo -e "[ ${GREEN}OK${NC} ] New script downloaded and verified."
    
    # Remove old file first to avoid permission/overwrite issues
    rm -f "$TARGET_FILE"
    
    # Move new file
    mv "$TMP_FILE" "$TARGET_FILE"
    chmod +x "$TARGET_FILE"
    
    echo -e "[ ${GREEN}INFO${NC} ] Restarting API Service..."
    systemctl restart api-backend
    echo -e "[ ${GREEN}OK${NC} ] API Service restarted."
else
    echo -e "[ ${RED}ERROR${NC} ] Download failed or verification failed!"
    echo -e "[ ${RED}ERROR${NC} ] The new script was not applied. Please check your connection."
    rm -f "$TMP_FILE"
fi

echo -e "[ ${GREEN}INFO${NC} ] API Xray Create Module Update Process Completed."

# Download setup.sh terbaru
#wget -q -O /usr/bin/setup.sh "${REPO}/setup.sh" && chmod +x /usr/bin/setup.sh

# 3. Terapkan Fix 'Clear Ghosting' (Scrollback Buffer Wipe)
# Mengganti 'clear' biasa dengan 'clear && printf "\033[3J"' pada script yang didownload
echo -e "[ ${GREEN}INFO${NC} ] Menerapkan fix terminal ghosting..."

files_to_fix=(
    #"/usr/bin/add-host"
    #"/usr/bin/ins-xray"
    #"/usr/bin/add-ws"
    #"/usr/bin/add-vless"
    #"/usr/bin/add-tr"
    #"/usr/bin/add-ssws"
    #"/usr/bin/usernew"
    #"/usr/bin/xp"
    #"/usr/bin/cek-expired"
    #"/usr/bin/menu"
    #"/usr/bin/menu-ssh"
    #"/usr/bin/setup.sh"
)

for file in "${files_to_fix[@]}"; do
    if [ -f "$file" ]; then
        sed -i "s/\bclear\b/clear \&\& printf '\\\033[3J'/g" "$file"
    fi
done

# 4. Buat Database Expired & Trash
#echo -e "[ ${GREEN}INFO${NC} ] Membuat database expired & trash users..."
#if [ ! -f /etc/expired-users.db ]; then
#    touch /etc/expired-users.db
#    chmod 644 /etc/expired-users.db
#    echo "Database expired-users.db dibuat."
#fi

#if [ ! -f /etc/expired-users-trash.db ]; then
#    touch /etc/expired-users-trash.db
#    chmod 644 /etc/expired-users-trash.db
#    echo "Database expired-users-trash.db dibuat."
#fi

# 5. Update Cron Job
#echo -e "[ ${GREEN}INFO${NC} ] Memperbarui Cron Job..."
# Hapus cron xp lama jika ada (yang harian atau duplikat)
#sed -i "/root xp/d" /etc/crontab
# Tambahkan cron xp baru (tiap 1 menit)
#echo "* * * * * root xp" >> /etc/crontab
# Restart cron
#service cron restart

# 6. Auto-Repair Xray & Nginx Config (SSH SNI Fix)
#echo -e "[ ${GREEN}INFO${NC} ] Menjalankan perbaikan sistem (HAProxy/Xray/Nginx)..."
#/usr/bin/ins-xray

echo -e "[ ${GREEN}INFO${NC} ] Update Selesai!"
#echo -e "[ ${GREEN}INFO${NC} ] Fitur Auto-Delete presisi (10 menit) sudah aktif."
echo -e "[ ${GREEN}INFO${NC} ] Timezone server sekarang: $(date)"
#echo -e "[ ${GREEN}INFO${NC} ] HAProxy Frontend & Xray/Nginx Backend telah dikonfigurasi."
#echo -e "[ ${GREEN}INFO${NC} ] Menu utama telah diperbarui. Ketik 'menu' untuk melihat tampilan baru."
