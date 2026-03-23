#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V1.0
# Auther  : NevermoreSSH
# (C) Copyright 2022
# =========================================

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

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

# ==========================================
# Cek apakah dijalankan interaktif atau non-interaktif (cron)
# ==========================================
if [ ! -t 0 ]; then
    # Jika non-interaktif (contoh: cronjob), terapkan random delay 2-10 menit
    # Ini membantu menghindari Rclone Rate Limit / Google Drive "403 Limit Exceeded"
    # karena banyak VPS yang menembak API di menit yang sama
    DELAY=$((RANDOM % 481 + 120))
    MINUTES=$((DELAY / 60))
    SECONDS=$((DELAY % 60))
    echo -e "[ ${orange}WARNING${NC} ] Cronjob terdeteksi, menerapkan jeda acak $MINUTES menit $SECONDS detik..."
    sleep $DELAY
fi

# Get Telegram Bot Credentials (Dipindah ke atas untuk mengirim notifikasi awal)
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

# Variabel untuk menampung message_id dari notifikasi awal
START_MESSAGE_ID=""

if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
    START_MSG="⏳ Memulai proses backup..."
    # Simpan response API telegram untuk mengambil message_id
    API_RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        --data-urlencode text="$START_MSG")
    # Ekstrak message_id menggunakan regex
    START_MESSAGE_ID=$(echo "$API_RESPONSE" | grep -oP '"message_id":\K\d+' | head -n 1)
fi

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

# Rclone Fallback Logic
# Acak urutan remote untuk membagi beban (Load Balancing) ke semua akun GDrive
# agar tidak terjadi "gang bang" (rate limit) pada remote pertama ("dr")
remotes=("dr" "dr1" "dr2" "dr3" "dr4")

# Fungsi untuk mengacak array menggunakan bash native RANDOM
for i in "${!remotes[@]}"; do
    random_idx=$((RANDOM % ${#remotes[@]}))
    # Swap element
    temp="${remotes[$i]}"
    remotes[$i]="${remotes[$random_idx]}"
    remotes[$random_idx]="$temp"
done

backup_success=false
used_remote=""
link=""

for remote in "${remotes[@]}"; do
    echo -e "[ ${green}INFO${NC} ] Mencoba backup menggunakan remote: ${remote}..."
    if rclone copy /root/$IP-$date-$domain-blueblue.zip ${remote}:backup/; then
        url=$(rclone link ${remote}:backup/$IP-$date-$domain-blueblue.zip)
        # Ekstrak ID file dari link rclone dengan regex
        id=$(echo "$url" | grep -oP '(?<=/d/)[a-zA-Z0-9_-]+|(?<=id=)[a-zA-Z0-9_-]+' | head -n 1)
        if [ -n "$id" ]; then
            link="https://drive.google.com/u/4/uc?id=${id}&export=download"
            backup_success=true
            used_remote="${remote}"
            echo -e "[ ${green}INFO${NC} ] Backup berhasil menggunakan remote: ${remote}"
            break
        else
            echo -e "[ ${orange}WARNING${NC} ] Berhasil upload ke ${remote}, namun gagal mendapatkan link (ID kosong). Mencoba remote lain..."
        fi
    else
        echo -e "[ ${orange}WARNING${NC} ] Gagal upload menggunakan remote: ${remote}. Mencoba remote lain..."
    fi
done

# Send notification to Telegram if configured
if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
    # Hapus pesan awal "⏳ Memulai proses backup..."
    if [ -n "$START_MESSAGE_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/deleteMessage" \
            -d chat_id="$CHAT_ID" \
            -d message_id="$START_MESSAGE_ID" > /dev/null
    fi

    if [ "$backup_success" = true ]; then
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
    else
        # Gagal Rclone, kirim file langsung ke Telegram
        echo -e "[ ${orange}WARNING${NC} ] Mengirim file backup ke Telegram..."

        # Kirim Document ke bot Telegram
        RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" \
            -F chat_id="$CHAT_ID" \
            -F document="@/root/$IP-$date-$domain-blueblue.zip" \
            -F caption="Backup VPS Gagal via Gdrive. File backup dikirim melalui Telegram.")

        # Ekstrak file_id dari response json Telegram menggunakan jq
        # Jika jq gagal atau tidak ada, sed/grep akan digunakan sebagai fallback
        FILE_ID=$(echo "$RESPONSE" | grep -oP '"file_id":"\K[^"]+' | head -n 1)

        if [ -n "$FILE_ID" ]; then
            msg="◇━━━━━━━━━━━━━━◇
 🔄Detail Backup VPS🔄
◇━━━━━━━━━━━━━━◇
IP VPS  : $IP
DOMAIN  : $domain
Tanggal : $date
◇━━━━━━━━━━━━━━◇
Id file   :
<code>$FILE_ID</code>
◇━━━━━━━━━━━━━━◇
Silahkan copy Id file dan restore di VPS baru"

            curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
                -d chat_id="$CHAT_ID" \
                --data-urlencode text="$msg" \
                -d parse_mode="HTML" > /dev/null
            echo -e "[ ${green}INFO${NC} ] File backup berhasil dikirim ke Telegram."

            # Set link untuk ditampilkan di layar (terminal)
            link="$FILE_ID"
        else
            # Jika gagal mengirim file
            msg="◇━━━━━━━━━━━━━━◇
 ❌Backup VPS GAGAL❌
◇━━━━━━━━━━━━━━◇
IP VPS  : $IP
DOMAIN  : $domain
Tanggal : $date
◇━━━━━━━━━━━━━━◇
Pesan :
Semua konfigurasi rclone (dr, dr1, dr2, dr3, dr4) gagal mengupload file backup, dan gagal mengirim ke Telegram.
◇━━━━━━━━━━━━━━◇"

            curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
                -d chat_id="$CHAT_ID" \
                --data-urlencode text="$msg" \
                -d parse_mode="HTML" > /dev/null
            echo -e "[ ${red}ERROR${NC} ] Gagal mengirim file backup ke Telegram."
            link="Gagal mendapatkan Link / Id file"
        fi
    fi
fi

clear && printf '\033[3J'
echo -e "\033[1;37mVPS Data Backup By NevermoreSSH\033[0m
\033[1;37mTelegram : https://t.me/todfix667 / @NevermoreSSH\033[0m"
echo ""
echo "Please Copy Link/Id File Below & Save In Notepad"
echo ""
echo -e "Your VPS IP ( \033[1;37m$IP\033[0m )"
echo ""
echo -e "\033[1;37m$link\033[0m"
echo ""
echo "If you want to restore data, please enter the link/Id file above"
rm -rf /root/backup
rm -f /root/$IP-$date-$domain-blueblue.zip
echo ""
