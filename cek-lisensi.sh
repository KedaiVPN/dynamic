#!/bin/bash
function disable_services() {
    local reason=$1
    local SERVER_IP=$(curl -s https://ipinfo.io/ip/)
    echo -e "────────────────────────────────────────────"
    echo -e " ⚠️       AKSES DI TOLAK         ⚠️"
    echo -e "────────────────────────────────────────────"
    echo -e "❌  SCRIPT LOCKED "
    echo -e "🔒 Your VPS  Has been Banned"
    echo -e "⚠️ Lisensi kedaluwarsa"
    echo -e "🌐 IP server anda: $SERVER_IP"
    echo -e "💡 Beli izin resmi hanya dari Admin!"
    echo -e "📞 Contact Admin:"
    echo -e "🌍 Telegram: https://t.me/Kedai_vpn"
    echo -e "📱 WhatsApp: https://wa.me/6287777694482"
    echo -e "────────────────────────────────────────────"
    
    if [ "$2" == "--check-only" ]; then
        exit 1
    fi

    # Send message to all terminals
    wall "⚠️ VPS BANNED / $reason. SCRIPT LOCKED ⚠️"

    # Stop all related services
    systemctl stop nginx
    systemctl stop xray
    systemctl stop stunnel4
    systemctl stop dropbear
    systemctl stop ws-stunnel
    systemctl stop haproxy

    # Disable them so they don't restart on boot
    systemctl disable nginx
    systemctl disable xray
    systemctl disable stunnel4
    systemctl disable dropbear
    systemctl disable ws-stunnel
    systemctl disable haproxy

    # Update crontab to check every 3 minutes when expired/invalid
    sed -i "/cek-lisensi/d" /etc/crontab
    echo "*/3 * * * * root /usr/local/bin/cek-lisensi" >> /etc/crontab
    systemctl restart cron
    exit 1
}

function enable_services() {
    if [ "$1" == "--check-only" ]; then
        return 0
    fi

    # Check if services are already running to avoid unnecessary restarts
    if ! systemctl is-active --quiet xray; then
        echo -e "✅ Lisensi Aktif. Menghidupkan ulang layanan VPS..."
        wall "✅ VPS UNBANNED / Lisensi Aktif. SCRIPT UNLOCKED ✅"

        systemctl enable nginx
        systemctl enable xray
        systemctl enable stunnel4
        systemctl enable dropbear
        systemctl enable ws-stunnel
        systemctl enable haproxy

        systemctl start nginx
        systemctl start xray
        systemctl start stunnel4
        systemctl start dropbear
        systemctl start ws-stunnel
        systemctl start haproxy
    fi
}

# Pengecekan hanya menggunakan file lokal (Hybrid Webhook Mode)
if [ ! -f /etc/xray/license_exp ]; then
    # Jika tidak ada file lisensi sama sekali, anggap belum terdaftar
    disable_services "Lisensi Tidak Ditemukan" "$1"
fi

local_exp=$(cat /etc/xray/license_exp)
# Validasi format tanggal untuk mencegah error date
if ! date -d "$local_exp" >/dev/null 2>&1; then
    disable_services "Format Lisensi Invalid" "$1"
fi

expiry_timestamp=$(date -d "$local_exp" +%s)
current_timestamp=$(date +%s)

if [ "$expiry_timestamp" -le "$current_timestamp" ]; then
    disable_services "Masa Aktif Sudah Habis" "$1"
fi

# Jika masih aktif, pastikan service berjalan
enable_services "$1"

if [ "$1" == "--check-only" ]; then
    exit 0
fi

# Pastikan cron berjalan 1 kali per hari saja untuk hemat resource,
# karena webhook akan memicu script ini secara instan saat ada perubahan.
sed -i '/cek-lisensi/d' /etc/crontab
echo "10 0 * * * root /usr/local/bin/cek-lisensi" >> /etc/crontab
systemctl restart cron

exit 0
