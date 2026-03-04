#!/bin/bash
# Script Auto Update untuk Fitur Timezone & Auto-Delete Presisi
# Created by Jules

# Warna
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "[ ${GREEN}INFO${NC} ] Memulai Update..."

# 1. Update Timezone ke Asia/Jakarta
echo -e "[ ${GREEN}INFO${NC} ] Mengatur Timezone ke Asia/Jakarta..."
timedatectl set-timezone Asia/Jakarta
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# 2. Download Script Baru
# Pastikan URL ini sesuai dengan raw repository Anda
REPO="https://raw.githubusercontent.com/KedaiVPN/dynamic/main"

echo -e "[ ${GREEN}INFO${NC} ] Mendownload script terbaru..."
# wget -q -O /usr/bin/add-vless "${REPO}/add-vless.sh" && chmod +x /usr/bin/add-vless
# wget -q -O /usr/bin/add-tr "${REPO}/add-tr.sh" && chmod +x /usr/bin/add-tr
# wget -q -O /usr/bin/menu-vless "${REPO}/menu-vless.sh" && chmod +x /usr/bin/menu-vless
# wget -q -O /usr/bin/menu-trojan "${REPO}/menu-trojan.sh" && chmod +x /usr/bin/menu-trojan
# wget -q -O /usr/bin/user-xrays "${REPO}/user-xrays.sh" && chmod +x /usr/bin/user-xrays

# Update menu & ws-stunnel untuk perbaikan kompatibilitas Ubuntu 22/Debian 12
wget -q -O /usr/bin/menu "${REPO}/menu4.sh" && chmod +x /usr/bin/menu
wget -q -O /usr/bin/menu-ssh "${REPO}/menu-ssh.sh" && chmod +x /usr/bin/menu-ssh
wget -q -O /usr/bin/menu-vmess "${REPO}/menu-vmess.sh" && chmod +x /usr/bin/menu-vmess
wget -q -O /usr/bin/menu-vless "${REPO}/menu-vless.sh" && chmod +x /usr/bin/menu-vless
wget -q -O /usr/bin/menu-trojan "${REPO}/menu-trojan.sh" && chmod +x /usr/bin/menu-trojan
wget -q -O /usr/bin/menu-ss "${REPO}/menu-ss.sh" && chmod +x /usr/bin/menu-ss
wget -q -O /usr/bin/cek-trafik "${REPO}/cek-trafik.sh" && chmod +x /usr/bin/cek-trafik
wget -q -O /usr/bin/cek-expired "${REPO}/cek-expired.sh" && chmod +x /usr/bin/cek-expired
wget -q -O /usr/bin/menu-vless "${REPO}/menu-vless.sh" && chmod +x /usr/bin/menu-vless
wget -q -O /usr/bin/running "${REPO}/running.sh" && chmod +x /usr/bin/running
wget -q -O /usr/bin/restart "${REPO}/restart.sh" && chmod +x /usr/bin/restart
wget -q -O /usr/local/bin/cek-lisensi "${REPO}/cek-lisensi.sh" && chmod +x /usr/local/bin/cek-lisensi
wget -q -O /usr/local/bin/ws-stunnel "${REPO}/ws-stunnel" && chmod +x /usr/local/bin/ws-stunnel
wget -q -O /usr/bin/backup "${REPO}/backup.sh" && chmod +x /usr/bin/backup
wget -q -O /usr/bin/restore "${REPO}/restore.sh" && chmod +x /usr/bin/restore
wget -q -O /usr/bin/clearlog "${REPO}/clearlog.sh" && chmod +x /usr/bin/clearlog
wget -q -O /usr/bin/xp "${REPO}/xp.sh" && chmod +x /usr/bin/xp

systemctl restart ws-stunnel >/dev/null 2>&1

# --- HOTFIX: APPLY DROPBEAR, HAPROXY, DAN BANNER FIX PADA SERVER YANG SUDAH JALAN ---
echo -e "[ ${GREEN}INFO${NC} ] Menerapkan patch Dropbear & HAProxy..."
# Fix Dropbear
cat > /etc/default/dropbear <<-END
NO_START=0
DROPBEAR_PORT=143
DROPBEAR_EXTRA_ARGS="-p 109"
DROPBEAR_BANNER="/etc/issue.net"
DROPBEAR_RECEIVE_WINDOW=65536
END
systemctl daemon-reload >/dev/null 2>&1
systemctl enable dropbear >/dev/null 2>&1
systemctl restart dropbear >/dev/null 2>&1

# Fix HAProxy
DEBIAN_FRONTEND=noninteractive apt-get install -f -y haproxy >/dev/null 2>&1
sed -i 's/ tfo//g' /etc/haproxy/haproxy.cfg
sed -i '/chroot/d' /etc/haproxy/haproxy.cfg
systemctl daemon-reload >/dev/null 2>&1
systemctl enable haproxy >/dev/null 2>&1
systemctl restart haproxy >/dev/null 2>&1

# Fix Banner Issue.net (Hapus duplikasi SSHD)
wget -q -O /etc/issue.net "${REPO}/issue.net"
chmod +x /etc/issue.net
sed -i '/Banner \/etc\/issue.net/d' /etc/ssh/sshd_config
echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
systemctl restart ssh >/dev/null 2>&1
systemctl restart sshd >/dev/null 2>&1
# --- END HOTFIX ---

# Hapus script menu backup lama yang sudah tidak digunakan
# rm -f /usr/bin/menu-bckp
# rm -f /usr/bin/bckpbot

# --- UPDATE API MODULES ONLY ---
# echo -e "[ ${GREEN}INFO${NC} ] Updating API Modules..."
# mkdir -p /usr/local/bin/api-modules

# update_api_module() {
#     local script_name="$1"
#     local verify_string="$2"
#     local tmp_file="/tmp/${script_name}"
#     local target_file="/usr/local/bin/api-modules/${script_name}"

#     echo -e "[ ${GREEN}INFO${NC} ] Updating ${script_name}..."
#     wget -q -O "$tmp_file" "${REPO}/api-modules/${script_name}?v=$(date +%s)"

#     if [ -f "$tmp_file" ] && grep -q "$verify_string" "$tmp_file"; then
#         echo -e "[ ${GREEN}OK${NC} ] ${script_name} downloaded and verified."
#         rm -f "$target_file"
#         mv "$tmp_file" "$target_file"
#         chmod +x "$target_file"
#     else
#         echo -e "[ ${RED}ERROR${NC} ] Failed to update ${script_name}!"
#         rm -f "$tmp_file"
#     fi
# }

# # Update API Create Module
# update_api_module "api-xray-create.sh" "grpc_link"

# # Update API Trial Module
# update_api_module "api-xray-trial.sh" "grpc_link"

# echo -e "[ ${GREEN}INFO${NC} ] Restarting API Service..."
# systemctl restart geovpn-api >/dev/null 2>&1 || systemctl restart api-backend >/dev/null 2>&1
# echo -e "[ ${GREEN}OK${NC} ] API Service restarted."
# echo -e "[ ${GREEN}INFO${NC} ] API Xray Create & Trial Modules Update Completed."

# 3. Terapkan Fix 'Clear Ghosting' (Scrollback Buffer Wipe)
# Mengganti 'clear' biasa dengan 'clear && printf "\033[3J"' pada script yang didownload
echo -e "[ ${GREEN}INFO${NC} ] Menerapkan fix terminal ghosting..."

files_to_fix=(
    "/usr/bin/menu-vless"
    "/usr/bin/menu-trojan"
    "/usr/bin/menu-ssh"
    "/usr/bin/menu-vmess"
    "/usr/bin/menu-ss"
    "/usr/bin/cek-trafik"
    "/usr/bin/cek-expired"
    "/usr/bin/menu"
    "/usr/bin/backup"
    "/usr/bin/restore"
    "/usr/bin/running"
    "/usr/bin/restart"
)

for file in "${files_to_fix[@]}"; do
    if [ -f "$file" ]; then
        sed -i "s/\bclear\b/clear \&\& printf '\\\033[3J'/g" "$file"
    fi
done

echo -e "[ ${GREEN}INFO${NC} ] Update Selesai!"
echo -e "[ ${GREEN}INFO${NC} ] Menu Footer Layout telah di-update."
echo -e "[ ${GREEN}INFO${NC} ] Timezone server sekarang: $(date)"
