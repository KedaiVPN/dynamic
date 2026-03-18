#!/bin/bash
# =========================================
# Setup UDP Custom (ePro) for HTTP Custom
# =========================================

echo -e "[ INFO ] Menginstall UDP Custom (ePro)..."

# Buat direktori UDP Custom
mkdir -p /root/udp
cd /root/udp

# Mengatur timezone (jika belum)
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# Download file binary udp-custom (dari link Google Drive user)
echo -e "[ INFO ] Mendownload binary udp-custom..."
wget -q --show-progress --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1_VyhL5BILtoZZTW4rhnUiYzc4zHOsXQ8' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p')&id=1_VyhL5BILtoZZTW4rhnUiYzc4zHOsXQ8" -O /root/udp/udp-custom && rm -rf /tmp/cookies.txt

chmod +x /root/udp/udp-custom

# Membuat konfigurasi default config.json
echo -e "[ INFO ] Membuat file config.json..."
cat << 'EOF2' > /root/udp/config.json
{
  "listen": ":36712",
  "stream_buffer": 33554432,
  "receive_buffer": 83886080,
  "auth": {
    "mode": "passwords"
  }
}
EOF2
chmod 644 /root/udp/config.json

# Mengecualikan port umum agar tidak terjadi bentrok.
# Termasuk: SSH (22, 2253, 40000), Dropbear (143, 109, 58080), Stunnel (447, 777, 442)
# OpenVPN (1194), Web/Nginx/HAProxy (80, 443, 81), Badvpn (7100, 7200, 7300), DNS (53, 5300), API (5888, 8443)
EXCLUDE_PORTS="22,2253,40000,143,109,58080,447,777,442,1194,80,443,81,53,5300,7100,7200,7300,5888,8443"
if [ ! -z "$1" ]; then
    EXCLUDE_PORTS="$EXCLUDE_PORTS,$1"
fi

echo -e "[ INFO ] Membuat service systemd untuk udp-custom..."
cat << EOF2 > /etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Custom by ePro Dev. Team
After=network.target

[Service]
User=root
Type=simple
ExecStart=/root/udp/udp-custom server -exclude $EXCLUDE_PORTS
WorkingDirectory=/root/udp/
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
EOF2

# Reload systemd, start & enable service
systemctl daemon-reload &>/dev/null
systemctl enable udp-custom &>/dev/null
systemctl start udp-custom &>/dev/null

echo -e "[ OKEY ] UDP Custom berhasil diinstall dan dijalankan."
