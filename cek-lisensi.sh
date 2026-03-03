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
    systemctl stop cron

    # Disable them so they don't restart on boot
    systemctl disable nginx
    systemctl disable xray
    systemctl disable stunnel4
    systemctl disable dropbear
    systemctl disable ws-stunnel
    systemctl disable cron
    exit 1
}

SERVER_IP=$(curl -sS ipv4.icanhazip.com)
if [ -z "$SERVER_IP" ]; then
    # Jika gagal mengambil IP lokal, lewati pengecekan (bisa jadi network offline sementara)
    exit 0
fi

license_data=$(curl -s "https://raw.githubusercontent.com/kedaivpn/izin/main/allowed")
if [ $? -ne 0 ] || [ -z "$license_data" ]; then
    # Jika github diblokir atau offline, gunakan data lokal terakhir untuk menghindari pemblokiran tidak sengaja
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

# Jika sukses, update file lokal untuk sinkronisasi (termasuk jika ada perubahan nama/tanggal)
mkdir -p /etc/xray
echo "$client_name" > /etc/xray/license_client
echo "$expiry_date_str" > /etc/xray/license_exp
exit 0
