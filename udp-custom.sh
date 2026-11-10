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
udp_downloaded=0
for udp_attempt in 1 2 3 4 5; do
    rm -f /root/udp/udp-custom.tmp /tmp/cookies.txt
    confirm_tok=$(wget --quiet --timeout=20 --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1Alr7rbAPlUEWh5i8j6iZ0HswuRsZZ_OV' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\1\n/p' || true)
    if wget -q --timeout=30 --tries=1 --show-progress --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=${confirm_tok}&id=1Alr7rbAPlUEWh5i8j6iZ0HswuRsZZ_OV" -O /root/udp/udp-custom.tmp && [ -s /root/udp/udp-custom.tmp ] && ! head -c 64 /root/udp/udp-custom.tmp | grep -qiE "<!doctype|<html"; then
        mv -f /root/udp/udp-custom.tmp /root/udp/udp-custom
        udp_downloaded=1
        break
    fi
    rm -f /root/udp/udp-custom.tmp /tmp/cookies.txt
    sleep 2
done
rm -f /tmp/cookies.txt
if [ "$udp_downloaded" -ne 1 ]; then
    echo -e "[ ERROR ] Gagal mendownload binary udp-custom setelah beberapa percobaan."
    exit 1
fi

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

echo -e "[ INFO ] Membuat service systemd untuk udp-custom..."

if [ -z "$1" ]; then
cat << EOF2 > /etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Custom by ePro Dev. Team
After=network.target

[Service]
User=root
Type=simple
ExecStart=/root/udp/udp-custom server
WorkingDirectory=/root/udp/
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
EOF2
else
cat << EOF2 > /etc/systemd/system/udp-custom.service
[Unit]
Description=UDP Custom by ePro Dev. Team
After=network.target

[Service]
User=root
Type=simple
ExecStart=/root/udp/udp-custom server -exclude $1
WorkingDirectory=/root/udp/
Restart=always
RestartSec=2s

[Install]
WantedBy=default.target
EOF2
fi

# Reload systemd, start & enable service
systemctl daemon-reload &>/dev/null
systemctl enable udp-custom &>/dev/null
systemctl start udp-custom &>/dev/null

echo -e "[ OKEY ] UDP Custom berhasil diinstall dan dijalankan."
