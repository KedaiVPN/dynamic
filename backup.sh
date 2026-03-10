#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V1.0
# Auther  : NevermoreSSH
# (C) Copyright 2022
# =========================================

red='\e[1;31m'
green='\e[0;32m'
purple='\e[0;35m'
orange='\e[0;33m'
NC='\e[0m'

# ==========================================
# Lock Mechanism untuk Mencegah Double Backup
# ==========================================
LOCK_FILE="/tmp/backup_process.lock"

# Cek apakah file lock sudah ada
if [ -e "$LOCK_FILE" ]; then
    # Baca PID dari lock file
    PID=$(cat "$LOCK_FILE")
    # Cek apakah proses dengan PID tersebut masih aktif
    if kill -0 "$PID" 2>/dev/null; then
        echo -e "[ ${red}ERROR${NC} ] Proses backup sedang berjalan (PID: $PID). Backup ini dihentikan untuk mencegah double backup."
        exit 1
    else
        # Jika PID tidak aktif (misal proses crash sebelumnya), hapus lock file yang stale
        echo -e "[ ${orange}WARNING${NC} ] Menghapus lock file usang."
        rm -f "$LOCK_FILE"
    fi
fi

# Buat lock file dengan PID saat ini
echo $$ > "$LOCK_FILE"

# Pastikan lock file dihapus saat script selesai atau dihentikan secara paksa (SIGINT, SIGTERM)
trap 'rm -f "$LOCK_FILE"; exit' INT TERM EXIT
# ==========================================

clear && printf '\033[3J'
IP=$(wget -qO- icanhazip.com);
IP=$(curl -s ipinfo.io/ip )
IP=$(curl -sS ipv4.icanhazip.com)
IP=$(curl -sS ifconfig.me )
date=$(date +"%Y-%m-%d-%H:%M:%S")
domain=$(cat /etc/xray/domain)
clear && printf '\033[3J'
echo " VPS Data Backup By NevermoreSSH "
sleep 1
echo -e "[ ${green}INFO${NC} ] Processing . . . "
mkdir -p /root/backup
sleep 1
clear && printf '\033[3J'
echo " Please Wait VPS Data Backup In Progress . . . "
echo " "
echo " Backup SSH & XRAY Account . . . "
#cp -r /root/.acme.sh /root/backup/ &> /dev/null
#cp -r /var/lib/premium-script/ /root/backup/premium-script
#cp -r /usr/local/etc/xray /root/backup/xray
cp -r /home/vps/public_html /root/backup/public_html
cp -r /etc/xray/ /root/backup/xray/ >/dev/null 2>&1
cp -r /etc/cron.d /root/backup/cron.d &> /dev/null
cp -r /etc/crontab /root/backup/crontab &> /dev/null
cp -r /etc/shadow /root/backup/shadow >/dev/null 2>&1
cp -r /etc/gshadow /root/backup/gshadow >/dev/null 2>&1
cp -r /etc/passwd /root/backup/passwd >/dev/null 2>&1
cp -r /etc/group /root/backup/group >/dev/null 2>&1
cd /root
zip -r $IP-$date-$domain-blueblue.zip backup > /dev/null 2>&1
rclone copy /root/$IP-$date-$domain-blueblue.zip dr:backup/
url=$(rclone link dr:backup/$IP-$date-$domain-blueblue.zip)
id=(`echo $url | grep '^https' | cut -d'=' -f2`)
link="https://drive.google.com/u/4/uc?id=${id}&export=download"

# Get Telegram Bot Credentials
BOT_TOKEN=""
CHAT_ID=""

if [ -f "/etc/nevermore-api/bot.conf" ]; then
    BOT_TOKEN=$(grep -w "BOT_TOKEN" /etc/nevermore-api/bot.conf | cut -d'=' -f2)
    CHAT_ID=$(grep -w "CHAT_ID" /etc/nevermore-api/bot.conf | cut -d'=' -f2)
elif [ -f "/root/botapi.conf" ]; then
    BOT_TOKEN=$(grep -w "toket" /root/botapi.conf | cut -d'=' -f2)
    CHAT_ID=$(grep -w "chat_idc" /root/botapi.conf | cut -d'=' -f2)
elif [ -f "/etc/geovpn/telegram.conf" ]; then
    BOT_TOKEN=$(grep -w "TOKEN" /etc/geovpn/telegram.conf | cut -d'=' -f2)
    CHAT_ID=$(grep -w "CHAT_ID" /etc/geovpn/telegram.conf | cut -d'=' -f2)
fi

# Send notification to Telegram if configured
if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
    msg="◇━━━━━━━━━━━━━━◇
 🔄Detail Backup VPS🔄
◇━━━━━━━━━━━━━━◇
IP VPS  : $IP
DOMAIN  : $domain
Tanggal : $date
◇━━━━━━━━━━━━━━◇
Link Backup   :
<code>$link</code>
◇━━━━━━━━━━━━━━◇
Silahkan copy Link dan restore di VPS baru"

    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        --data-urlencode text="$msg" \
        -d parse_mode="HTML" > /dev/null
fi

clear && printf '\033[3J'
echo -e "\033[1;37mVPS Data Backup By NevermoreSSH\033[0m
\033[1;37mTelegram : https://t.me/todfix667 / @NevermoreSSH\033[0m"
echo ""
echo "Please Copy Link Below & Save In Notepad"
echo ""
echo -e "Your VPS IP ( \033[1;37m$IP\033[0m )"
echo ""
echo -e "\033[1;37m$link\033[0m"
echo ""
echo "If you want to restore data, please enter the link above"
rm -rf /root/backup
rm -r /root/$IP-$date-$domain-blueblue.zip
echo ""
