#!/bin/bash
function disable_services() {
    local reason=$1
    echo -e "────────────────────────────────────────────"
    echo -e " ⚠️       AKSES DI TOLAK         ⚠️"
    echo -e "────────────────────────────────────────────"
    echo -e "        ❌  SCRIPT LOCKED ❌"
    echo -e "  🔒 Your VPS  Has been Banned"
    echo -e "  ⚠️  $reason ⚠️"
    echo -e "  💡 Beli izin resmi hanya dari Admin!"
    echo -e "  📞 Contact Admin:"
    echo -e "  🌍 Telegram: https://t.me/Kedai_vpn"
    echo -e "  📱 WhatsApp: https://wa.me/6287777694482"
    echo -e "────────────────────────────────────────────"
    
    # Send message to all terminals
    wall "⚠️ VPS BANNED / $reason. SCRIPT LOCKED ⚠️"

    # Stop all related services
    systemctl stop nginx
    systemctl stop xray
    systemctl stop stunnel4
    systemctl stop dropbear
    systemctl stop ws-stunnel

    # Disable them so they don't restart on boot
    systemctl disable nginx
    systemctl disable xray
    systemctl disable stunnel4
    systemctl disable dropbear
    systemctl disable ws-stunnel

    # Update crontab to check every 10 minutes when expired/invalid
    sed -i '/cek-lisensi/d' /etc/crontab
    echo "*/10 * * * * root /usr/local/bin/cek-lisensi" >> /etc/crontab
    systemctl restart cron
    exit 1
}

function enable_services() {
    # Check if services are already running to avoid unnecessary restarts
    if ! systemctl is-active --quiet xray; then
        echo -e "✅ Lisensi Aktif. Menghidupkan ulang layanan VPS..."
        wall "✅ VPS UNBANNED / Lisensi Aktif. SCRIPT UNLOCKED ✅"

        systemctl enable nginx
        systemctl enable xray
        systemctl enable stunnel4
        systemctl enable dropbear
        systemctl enable ws-stunnel

        systemctl start nginx
        systemctl start xray
        systemctl start stunnel4
        systemctl start dropbear
        systemctl start ws-stunnel
    fi
}

SERVER_IP=$(curl -sS ipv4.icanhazip.com)
if [ -z "$SERVER_IP" ]; then
    # Jika gagal mengambil IP lokal, lewati pengecekan (bisa jadi network offline sementara)
    exit 0
fi

# Fetch HTTP Status code and Body
http_response=$(curl -s -w "%{http_code}" "https://raw.githubusercontent.com/kedaivpn/izin/main/allowed")
http_code=$(tail -n1 <<< "$http_response")
license_data=$(sed '$ d' <<< "$http_response")

# Validasi apakah curl gagal koneksi (exit code) ATAU HTTP status bukan 200 (misal 404/429/500 dll) ATAU data kosong
if [ $? -ne 0 ] || [ "$http_code" -ne 200 ] || [ -z "$license_data" ]; then
    # Jika github diblokir, kena rate limit, atau offline, gunakan data lokal terakhir
    if [ -f /etc/xray/license_exp ]; then
        local_exp=$(cat /etc/xray/license_exp)
        expiry_timestamp=$(date -d "$local_exp" +%s)
        current_timestamp=$(date +%s)
        if [ "$expiry_timestamp" -le "$current_timestamp" ]; then
            disable_services "Masa Aktif Sudah Habis (Local Check)"
        fi
    fi
    exit 0
fi

license_entry=$(echo "$license_data" | grep -w "$SERVER_IP")
if [ -z "$license_entry" ]; then
    disable_services "IP Tidak Terdaftar"
fi

client_name=$(echo "$license_entry" | awk '{print $1}')
expiry_date_str=$(echo "$license_entry" | awk '{print $2}')

expiry_timestamp=$(date -d "$expiry_date_str" +%s)
current_timestamp=$(date +%s)

if [ "$expiry_timestamp" -le "$current_timestamp" ]; then
    disable_services "Masa Aktif Sudah Habis"
fi

# Jika sukses, hidupkan kembali service jika sebelumnya mati
enable_services

# Jika sukses, update file lokal untuk sinkronisasi (termasuk jika ada perubahan nama/tanggal)
mkdir -p /etc/xray
echo "$client_name" > /etc/xray/license_client
echo "$expiry_date_str" > /etc/xray/license_exp

# Update crontab to check at 00:10 when active
sed -i '/cek-lisensi/d' /etc/crontab
echo "10 0 * * * root /usr/local/bin/cek-lisensi" >> /etc/crontab
systemctl restart cron

exit 0
