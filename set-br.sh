#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V3.0.7
# Auther  : KedaiSSH
# (C) Copyright 2026
# =========================================
export Server_URL="raw.githubusercontent.com/KedaiVPN/dynamic/main"

clear && printf '\033[3J'
dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
biji=`date +"%Y-%m-%d" -d "$dateFromServer"`
#########################
MYIP=$(wget -qO- ipv4.icanhazip.com);
MYIP=$(curl -s ipinfo.io/ip )
MYIP=$(curl -sS ipv4.icanhazip.com)
MYIP=$(curl -sS ifconfig.me )
clear && printf '\033[3J'
red='\e[1;31m'
green='\e[0;32m'
yell='\e[1;33m'
tyblue='\e[1;36m'
purple='\e[0;35m'
NC='\e[0m'
purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

red='\e[1;31m'
green='\e[0;32m'
NC='\e[0m'
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

download_with_retry() {
    local url="$1"
    local dest="$2"
    local max_attempts="${3:-5}"
    local delay="${4:-2}"
    local tmp_file
    local attempt=1

    mkdir -p "$(dirname "$dest")"
    tmp_file=$(mktemp "${dest}.tmp.XXXXXX") || return 1

    while [ "$attempt" -le "$max_attempts" ]; do
        rm -f "$tmp_file"
        if command -v wget >/dev/null 2>&1; then
            if wget -q --timeout=20 --tries=1 -O "$tmp_file" "$url" && [ -s "$tmp_file" ]; then
                mv -f "$tmp_file" "$dest"
                return 0
            fi
        fi
        rm -f "$tmp_file"
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL --connect-timeout 15 --max-time 120 -o "$tmp_file" "$url" && [ -s "$tmp_file" ]; then
                mv -f "$tmp_file" "$dest"
                return 0
            fi
        fi
        rm -f "$tmp_file"
        if [ "$attempt" -lt "$max_attempts" ]; then
            sleep "$delay"
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

#curl https://rclone.org/install.sh | bash
apt install rclone -y
printf "q\n" | rclone config
download_with_retry "https://${Server_URL}/rclone.conf" "/root/.config/rclone/rclone.conf" || exit 1
git clone  https://github.com/MrMan21/wondershaper.git
cd wondershaper
make install
cd
rm -rf wondershaper
cd /usr/bin
# Download or copy scripts locally
if [ -f "/root/backup.sh" ]; then
    cp -f /root/backup.sh /usr/bin/backup
else
    download_with_retry "https://${Server_URL}/backup.sh" "/usr/bin/backup" || exit 1
fi

if [ -f "/root/restore.sh" ]; then
    cp -f /root/restore.sh /usr/bin/restore
else
    download_with_retry "https://${Server_URL}/restore.sh" "/usr/bin/restore" || exit 1
fi

if [ -f "/root/logcleaner.sh" ]; then
    cp -f /root/logcleaner.sh /usr/bin/cleaner
else
    download_with_retry "https://${Server_URL}/logcleaner.sh" "/usr/bin/cleaner" || exit 1
fi

chmod +x /usr/bin/backup
chmod +x /usr/bin/restore
chmod +x /usr/bin/cleaner
cd
if [ ! -f "/etc/cron.d/cleaner" ]; then
cat> /etc/cron.d/cleaner << END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
*/2 * * * * root /usr/bin/cleaner
END
fi
service cron restart > /dev/null 2>&1
rm -f /root/set-br.sh
