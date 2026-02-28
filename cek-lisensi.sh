#!/bin/bash
MYIP=$(curl -sS ipv4.icanhazip.com)
izin=$(curl -sS https://raw.githubusercontent.com/kedaivpn/izin/main/allowed | grep -w $MYIP)

function disable_services() {
    echo -e "────────────────────────────────────────────"
    echo -e " ⚠️       AKSES DI TOLAK         ⚠️"
    echo -e "────────────────────────────────────────────"
    echo -e "        ❌  SCRIPT LOCKED ❌"
    echo -e "  🔒 Your VPS  Has been Banned"
    echo -e "  ⚠️  Masa Aktif Sudah Habis ⚠️"
    echo -e "  💡 Beli izin resmi hanya dari Admin!"
    echo -e "  📞 Contact Admin:"
    echo -e "  🌍 Telegram: https://t.me/Kedai_vpn"
    echo -e "  📱 WhatsApp: https://wa.me/6287777694482"
    echo -e "────────────────────────────────────────────"
    
    # Send message to all terminals
    wall "⚠️ VPS BANNED / LISENSI HABIS. SCRIPT LOCKED ⚠️"

    # Stop all related services
    systemctl stop nginx
    systemctl stop xray
    systemctl stop stunnel5
    systemctl stop dropbear
    systemctl stop ws-stunnel
    systemctl stop cron

    # Disable them so they don't restart on boot
    systemctl disable nginx
    systemctl disable xray
    systemctl disable stunnel5
    systemctl disable dropbear
    systemctl disable ws-stunnel
    systemctl disable cron
    exit 1
}

if [[ -z "$izin" ]]; then
    disable_services
else
    Client=$(echo "$izin" | awk '{print $1}')
    Exp=$(echo "$izin" | awk '{print $2}')
    d1=$(date -d "$Exp" +%s)
    d2=$(date -d "today" +%s)
    certifacate=$(((d1 - d2) / 86400))
    if [[ "$certifacate" -le 0 ]]; then
        disable_services
    fi
    mkdir -p /etc/xray
    echo "$Client" > /etc/xray/license_client
    echo "$Exp" > /etc/xray/license_exp
fi
