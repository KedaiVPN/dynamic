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
# PROVIDED
creditt=$(cat /root/provided)
# BANNER COLOUR
banner_colour=$(cat /etc/banner)
# TEXT ON BOX COLOUR
box=$(cat /etc/box)
# LINE COLOUR
line=$(cat /etc/line)
# TEXT COLOUR ON TOP
text=$(cat /etc/text)
# TEXT COLOUR BELOW
below=$(cat /etc/below)
# BACKGROUND TEXT COLOUR
back_text=$(cat /etc/back)
# NUMBER COLOUR
number=$(cat /etc/number)

red='\e[1;31m'
green='\e[0;32m'
purple='\e[0;35m'
orange='\e[0;33m'
NC='\e[0m'
clear && printf '\033[3J'
echo ""
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"
echo -e   "  \e[$back_text            \e[30m[\e[$box RESTORE SSH & XRAY ACCOUNT \e[30m ]\e[1m            \e[m"
echo -e   "  \e[$line═══════════════════════════════════════════════════════\e[m"
echo ""
echo " This Feature Can Only Be Used According To VPS Data With This Autoscript"
echo " Please Choose The Restore Method:"
echo ""
echo " 1. Via Gdrive"
echo " 2. Via Telegram"
echo ""
read -rp " Pilih Opsi Restore (1/2): " -e opsi_restore
echo ""

if [[ "$opsi_restore" == "1" ]]; then
    read -rp " Link File: " -e url
    wget -O backup.zip "$url"
elif [[ "$opsi_restore" == "2" ]]; then
    read -rp " Masukkan Id File Telegram: " -e file_id
    BOT_TOKEN=""
    if [ -f "/etc/nevermore-api/bot.conf" ]; then
        BOT_TOKEN=$(grep -w "BOT_TOKEN" /etc/nevermore-api/bot.conf | cut -d'=' -f2)
    elif [ -f "/root/botapi.conf" ]; then
        BOT_TOKEN=$(grep -w "toket" /root/botapi.conf | cut -d'=' -f2)
    elif [ -f "/etc/geovpn/telegram.conf" ]; then
        BOT_TOKEN=$(grep -w "TOKEN" /etc/geovpn/telegram.conf | cut -d'=' -f2)
    fi

    if [ -z "$BOT_TOKEN" ]; then
        echo -e "[ ${red}ERROR${NC} ] Bot Token tidak ditemukan, tidak dapat mengunduh dari Telegram."
        exit 1
    fi

    FILE_INFO=$(curl -s -X GET "https://api.telegram.org/bot$BOT_TOKEN/getFile?file_id=$file_id")
    FILE_PATH=$(echo "$FILE_INFO" | grep -oP '"file_path":"\K[^"]+' | head -n 1)

    if [ -z "$FILE_PATH" ]; then
        echo -e "[ ${red}ERROR${NC} ] Gagal mendapatkan file_path dari Telegram. Pastikan Id File benar."
        exit 1
    fi

    DOWNLOAD_URL="https://api.telegram.org/file/bot$BOT_TOKEN/$FILE_PATH"
    echo -e "[ ${green}INFO${NC} ] Mengunduh file backup dari Telegram..."
    wget -qO backup.zip "$DOWNLOAD_URL"

    if [ ! -s backup.zip ]; then
        echo -e "[ ${red}ERROR${NC} ] File backup kosong atau gagal diunduh."
        exit 1
    fi
else
    echo -e "[ ${red}ERROR${NC} ] Pilihan tidak valid."
    exit 1
fi

#read -rp " Password File: " -e InputPass
#unzip -P $InputPass /root/backup.zip &> /dev/null
unzip backup.zip
rm -f backup.zip
sleep 1
echo -e "[ ${green}INFO${NC} ] Start Restore . . . "
#cp -r /root/backup/.acme.sh /root/ &> /dev/null
#cp -r /root/backup/premium-script /var/lib/ &> /dev/null
#cp -r /root/backup/xray /usr/local/etc/ &> /dev/null
cp -r /root/backup/public_html /home/vps/ &> /dev/null
cp -r /root/backup/xray/ /etc/ >/dev/null
cp -r /root/backup/crontab /etc/ &> /dev/null
cp -r /root/backup/cron.d /etc/ &> /dev/null
cp -r /root/backup/shadow /etc/ &> /dev/null
cp -r /root/backup/gshadow /etc/ &> /dev/null
cp -r /root/backup/passwd /etc/ &> /dev/null
cp -r /root/backup/group /etc/ &> /dev/null
rm -rf /root/backup
rm -f backup.zip
echo ""
echo -e "[ ${green}INFO${NC} ] VPS Data Restore Complete !"
echo ""
echo -e "[ ${green}INFO${NC} ] Back to menu . . . "
systemctl restart nginx
systemctl restart xray.service
systemctl restart haproxy
service cron restart
sleep 5
system
clear && printf '\033[3J'
