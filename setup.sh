#!/bin/bash
clear && printf '\033[3J'

# // Visual Indicator for initial load
echo -e "\033[0;33m[ INFO ]\033[0m Sedang memverifikasi lisensi IP VPS Anda..."

dateFromServer=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')

# // Root Checking
if [ "${EUID}" -ne 0 ]; then
		echo -e "${EROR} Please Run This Script As Root User !"
		exit 1
fi

# // License Verification (Vercel Backend)
function verify_license() {
    echo -e "\033[0;33m[ INFO ]\033[0m Sedang memverifikasi lisensi instalasi Anda..."
    local SERVER_IP
    SERVER_IP=$(curl -fsSL --retry 3 --max-time 10 ipv4.icanhazip.com 2>/dev/null || curl -fsSL --max-time 10 https://api.ipify.org 2>/dev/null || curl -fsSL --max-time 10 https://ifconfig.me 2>/dev/null || true)
    if [ -z "$SERVER_IP" ]; then
        echo -e "\033[0;31m[ ERROR ]\033[0m Gagal mengambil IP server. Periksa koneksi internet Anda."
        exit 1
    fi

    local VERCEL_API_URL="https://licence-manager-nu.vercel.app"

    local sync_response
    sync_response=$(curl -fsSL --retry 3 --max-time 15 "${VERCEL_API_URL}/api/check/tunneling?ip=${SERVER_IP}" 2>/dev/null || echo "")
    
    local is_valid
    is_valid=$(echo "$sync_response" | grep -E -o '"valid"\s*:\s*true')
    client_name=$(echo "$sync_response" | grep -E -o '"client_name"\s*:\s*"[^"]+' | awk -F'"' '{print $4}')
    expiry_date_str=$(echo "$sync_response" | grep -E -o '"expired_date"\s*:\s*"[^"]+' | awk -F'"' '{print $4}')

    if [ -z "$is_valid" ] || [ -z "$client_name" ] || [ -z "$expiry_date_str" ]; then
        echo -e "────────────────────────────────────────────"
        echo -e " ⚠️       AKSES DI TOLAK         ⚠️"
        echo -e "────────────────────────────────────────────"
        echo -e "        ❌  SCRIPT LOCKED ❌"
        echo -e "  🔒 Your VPS  Has been Banned"
        echo -e "  ⚠️  Lisensi Tidak Terdaftar / Invalid ⚠️"
        echo -e "  IP Anda: $SERVER_IP"
        echo -e "  💡 Beli izin resmi hanya dari Admin!"
        echo -e "  📞 Contact Admin:"
        echo -e "  🌍 Telegram: https://t.me/Kedai_vpn"
        echo -e "  📱 WhatsApp: https://wa.me/6287777694482"
        echo -e "────────────────────────────────────────────"
        exit 1
    fi
    
    echo -e "\033[0;32m[ OKEY ]\033[0m Lisensi terverifikasi dari Vercel! (Client: $client_name, Expired: $expiry_date_str)"
    sleep 2
    
    mkdir -p /etc/xray
    echo "$client_name" > /etc/xray/license_client
    echo "$expiry_date_str" > /etc/xray/license_exp
}

verify_license

# // Cek old script
# Mode AUTO_INSTALL (dari daemon): re-install hanya bila FORCE_REINSTALL=1.
# Tanpa FORCE -> berhenti dengan exit code 10 (needs_confirmation) agar
# data server lama tidak pernah dihapus tanpa konfirmasi eksplisit.
if [[ -r /etc/xray/domain ]]; then
echo -e "[ \033[0;33mINFO\033[0m ] Having Script Detected !"
if [[ -n "$AUTO_INSTALL" ]]; then
    if [[ -z "$FORCE_REINSTALL" ]]; then
        echo -e "[ \033[0;31mSTOP\033[0m ] Script sudah terpasang. Kirim FORCE_REINSTALL=1 untuk ganti."
        exit 10
    fi
    echo -e "[ \033[0;33mINFO\033[0m ] FORCE_REINSTALL aktif, replacing script!"
    rm -rf /var/lib/scrz-prem
else
echo -e "[ \033[0;33mINFO\033[0m ] If You Replacing Script, All Client Data On This VPS Will Be Cleanup !"
read -p "Are You Sure Wanna Replace Script ? (Y/N) " josdong
if [[ $josdong == "Y" ]] || [[ $josdong == "y" ]]; then
    clear && printf '\033[3J'
    echo -e "[ \033[0;33mINFO\033[0m ] Starting Replacing Script !"
    rm -rf /var/lib/scrz-prem 
elif [[ $josdong == "N" ]] || [[ $josdong == "n" ]]; then
    echo -e "[ \033[0;33mINFO\033[0m ] Action Canceled !"
    exit 1
else
    echo -e "[ \033[0;31mERROR\033[0m ] Your Input Is Wrong !"
    exit 1
fi
fi
clear && printf '\033[3J'
fi

echo -e "\033[0;32m[ INFO ]\033[0m Cleaning up old directories and packages before starting..."
# // Remove Old Directories first so we don't wipe our newly inputted domain
rm -fr /usr/local/bin/xray
rm -fr /usr/local/bin/stunnel
rm -fr /usr/local/bin/stunnel4
rm -fr /etc/nginx
rm -fr /var/lib/scrz-prem/
rm -fr /usr/bin/xray
rm -fr /etc/xray
rm -fr /usr/local/etc/xray

# // Making Directory 
mkdir -p /usr/bin
mkdir -p /etc/nginx
mkdir -p /var/lib/scrz-prem/
mkdir -p /usr/bin/xray
mkdir -p /etc/xray
mkdir -p /usr/local/etc/xray

# // Input Domain
echo -e "\033[0;34m┌─────────────────────────────────────────┐\033[0m"
echo -e "                          ⇱ INSTALL DOMAIN ⇲            "
echo -e "\033[0;34m└─────────────────────────────────────────┘\033[0m"
if [[ -n "$AUTO_INSTALL" && -n "$DOMAIN" ]]; then
    # Mode otomatis dari daemon installer — domain sudah dikirim via env
    domain="$DOMAIN"
    echo -e "[ \033[0;32mOKEY\033[0m ] Domain diterima dari env: $domain"
else
    read -rp "Masukkan Domain Anda: " domain
fi
echo "IP=$domain" > /var/lib/scrz-prem/ipvps.conf
echo $domain > /etc/xray/domain

# // Restore License to the newly created /etc/xray/ folder
echo "$client_name" > /etc/xray/license_client
echo "$expiry_date_str" > /etc/xray/license_exp

# // Install Basic Packages
echo -e "\033[0;32m[ INFO ]\033[0m Updating and installing basic packages..."
export DEBIAN_FRONTEND=noninteractive
apt --fix-missing update
apt update
apt upgrade -y
apt install -y bzip2 gzip coreutils screen dpkg wget vim curl nano zip unzip socat

# // Exporting Language to UTF-8
export LANG='en_US.UTF-8'
export LANGUAGE='en_US.UTF-8'

# // Export Color & Information
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export LIGHT='\033[0;37m'
export NC='\033[0m'
BIRed='\033[1;91m'
red='\e[1;31m'
bo='\e[1m'
red='\e[1;31m'
green='\e[0;32m'
yell='\e[1;33m'
tyblue='\e[1;36m'
purple() { echo -e "\\033[35;1m${*}\\033[0m"; }
tyblue() { echo -e "\\033[36;1m${*}\\033[0m"; }
yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }
# // Export Banner Status Information
export EROR="[${RED} ERROR ${NC}]"
export INFO="[${YELLOW} INFO ${NC}]"
export OKEY="[${GREEN} OKEY ${NC}]"
export PENDING="[${YELLOW} PENDING ${NC}]"
export SEND="[${YELLOW} SEND ${NC}]"
export RECEIVE="[${YELLOW} RECEIVE ${NC}]"

# // Export Align
export BOLD="\e[1m"
export WARNING="${RED}\e[5m"
export UNDERLINE="\e[4m"

# // Exporting URL Host
export Server_URL="raw.githubusercontent.com/KedaiVPN/dynamic/main/test"
export Server1_URL="raw.githubusercontent.com/KedaiVPN/dynamic/main/limit"
export Server_Port="443"
export Server_IP="underfined"
export Script_Mode="Stable"
export Auther=".geovpn"

# // Exporting Script Version
export VERSION="1.1"
 
# // Exporint IP AddressInformation
export IP=$( curl -s https://ipinfo.io/ip/ )

# // Set Time To Jakarta / GMT +7
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

echo -e "${GREEN}Starting Installation............${NC}"
# // Go To Root Directory
cd /root/
# // Remove
apt-get remove --purge nginx* -y
apt-get remove --purge nginx-common* -y
apt-get remove --purge nginx-full* -y
apt-get remove --purge dropbear* -y
apt-get remove --purge stunnel4* -y
apt-get remove --purge apache2* -y
apt-get remove --purge ufw* -y
apt-get remove --purge firewalld* -y
apt-get remove --purge exim4* -y
apt autoremove -y

# // Update
apt update -y

# // Auto-answer iptables-persistent
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections

# // Install Requirement Tools
apt-get --reinstall --fix-missing install -y sudo dpkg psmisc socat jq ruby wondershaper python3 tmux nmap bzip2 gzip coreutils wget screen rsyslog iftop htop net-tools zip unzip wget vim net-tools curl nano sed screen gnupg gnupg1 bc apt-transport-https build-essential gcc g++ automake make autoconf perl m4 dos2unix dropbear libreadline-dev zlib1g-dev libssl-dev dirmngr libxml-parser-perl neofetch git lsof iptables iptables-persistent
apt-get --reinstall --fix-missing install -y libreadline-dev zlib1g-dev libssl-dev python3 screen curl jq bzip2 gzip coreutils rsyslog iftop htop zip unzip net-tools sed gnupg gnupg1 bc sudo apt-transport-https build-essential dirmngr libxml-parser-perl neofetch screenfetch git lsof openssl easy-rsa fail2ban python3-systemd tmux vnstat dropbear libsqlite3-dev socat cron bash-completion ntpdate xz-utils sudo apt-transport-https gnupg2 gnupg1 dnsutils lsb-release chrony
gem install lolcat

# // Update & Upgrade
apt update -y
apt upgrade -y
apt dist-upgrade -y

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

# // Clear
clear && printf '\033[3J'
clear && printf '\033[3J' && clear && printf '\033[3J' && clear && printf '\033[3J'
clear && printf '\033[3J';clear && printf '\033[3J';clear && printf '\033[3J'

echo -e "[ \033[0;32mINFO\033[0m ] Starting renew gen-ssl... " 
sleep 2
mkdir -p /root/.acme.sh
if ! download_with_retry "https://acme-install.netlify.app/acme.sh" "/root/.acme.sh/acme.sh"; then
    echo -e "\033[0;31m[ ERROR ]\033[0m Gagal mengunduh acme.sh."
    exit 1
fi
chmod +x /root/.acme.sh/acme.sh
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc

# // Create HAProxy PEM
cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/xray/xray.pem
chmod 644 /etc/xray/xray.pem

echo -e "[ ${GREEN}INFO${NC} ] Renew gen-ssl done... " 
sleep 2

# // Tuning Conntrack Kernel
tuning_conntrack() {
    echo -e "[ \033[0;32mINFO\033[0m ] Tuning kernel conntrack..."

    # 1. Pastikan modul nf_conntrack dimuat otomatis saat boot sebelum systemd-sysctl
    mkdir -p /etc/modules-load.d
    cat > /etc/modules-load.d/conntrack.conf << 'EOF'
nf_conntrack
EOF

    # 2. Muat modul nf_conntrack jika belum termuat
    if ! lsmod 2>/dev/null | grep -q nf_conntrack; then
        modprobe nf_conntrack >/dev/null 2>&1 || true
    fi

    # 3. Terapkan langsung tanpa reboot
    sysctl -w net.netfilter.nf_conntrack_max=2000000 >/dev/null 2>&1 || true
    sysctl -w net.netfilter.nf_conntrack_tcp_timeout_time_wait=30 >/dev/null 2>&1 || true

    # 4. Buat permanen (tulis ulang / overwrite, JANGAN append)
    mkdir -p /etc/sysctl.d
    cat > /etc/sysctl.d/99-conntrack.conf << 'EOF'
net.netfilter.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
EOF
    sysctl --system >/dev/null 2>&1 || true

    # 5. Verifikasi dan log
    local current_max=""
    if [ -r /proc/sys/net/netfilter/nf_conntrack_max ]; then
        current_max=$(cat /proc/sys/net/netfilter/nf_conntrack_max 2>/dev/null || true)
    fi

    if [ "$current_max" = "2000000" ]; then
        echo -e "[ \033[0;32mOKEY\033[0m ] nf_conntrack_max berhasil disetel: $current_max"
    else
        echo -e "[ \033[0;33mWARN\033[0m ] nf_conntrack_max bernilai '${current_max:-unknown}' (diharapkan 2000000), instalasi tetap dilanjutkan"
    fi
}

tuning_conntrack

# // Tuning Buffer Socket UDP Default (mencegah packet drop saat burst SlowDNS/UDP Custom)
tuning_udp_buffer() {
    echo -e "[ \033[0;32mINFO\033[0m ] Tuning buffer socket UDP default..."
    sed -i '/^[[:space:]]*net\.core\.rmem_default[[:space:]]*=/d' /etc/sysctl.conf 2>/dev/null || true
    sed -i '/^[[:space:]]*net\.core\.wmem_default[[:space:]]*=/d' /etc/sysctl.conf 2>/dev/null || true
    mkdir -p /etc/sysctl.d
    cat > /etc/sysctl.d/99-udp-buffer.conf << 'EOF'
net.core.rmem_default = 2097152
net.core.wmem_default = 2097152
EOF
    sysctl -w net.core.rmem_default=2097152 >/dev/null 2>&1 || true
    sysctl -w net.core.wmem_default=2097152 >/dev/null 2>&1 || true
    sysctl --system >/dev/null 2>&1 || true
}

tuning_udp_buffer

#install vnstat
echo -e "$white\033[0;34m┌─────────────────────────────────────────┐${NC}"
echo -e " \E[41;1;39m           ⇱ Install vnStat ⇲            \E[0m$NC"
echo -e "$white\033[0;34m└─────────────────────────────────────────┘${NC}"
sleep 1 
if [ -s "vnstat.sh" ]; then
    chmod +x vnstat.sh && ./vnstat.sh
elif download_with_retry "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/vnstat.sh" "vnstat.sh"; then
    chmod +x vnstat.sh && ./vnstat.sh
else
    echo -e "${RED}[ ERROR ] Gagal mengunduh vnstat.sh.${NC}"
    exit 1
fi

#install ssh-vpn
echo -e "$white\033[0;34m┌─────────────────────────────────────────┐${NC}"
echo -e " \E[41;1;39m          ⇱ Install SSH / WS ⇲           \E[0m$NC"
echo -e "$white\033[0;34m└─────────────────────────────────────────┘${NC}"
sleep 1
if [ -s "ssh-vpn.sh" ]; then
    chmod +x ssh-vpn.sh && ./ssh-vpn.sh
elif download_with_retry "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/ssh-vpn.sh" "ssh-vpn.sh"; then
    chmod +x ssh-vpn.sh && ./ssh-vpn.sh
else
    echo -e "${RED}[ ERROR ] Gagal mengunduh ssh-vpn.sh.${NC}"
    exit 1
fi

#install udp-custom
echo -e "$white\033[0;34m┌─────────────────────────────────────────┐${NC}"
echo -e " \E[41;1;39m          ⇱ Install UDP Custom ⇲          \E[0m$NC"
echo -e "$white\033[0;34m└─────────────────────────────────────────┘${NC}"
sleep 1
if [ -s "udp-custom.sh" ]; then
    chmod +x udp-custom.sh && ./udp-custom.sh
elif download_with_retry "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/udp-custom.sh" "udp-custom.sh"; then
    chmod +x udp-custom.sh && ./udp-custom.sh
else
    echo -e "${RED}[ ERROR ] Gagal mengunduh udp-custom.sh.${NC}"
    exit 1
fi

#install ins-xray
echo -e "$white\033[0;34m┌─────────────────────────────────────────┐${NC}"
echo -e " \E[41;1;39m            ⇱ Install Xray ⇲             \E[0m$NC"
echo -e "$white\033[0;34m└─────────────────────────────────────────┘${NC}"
sleep 1 
if [ -s "ins-xray.sh" ]; then
    chmod +x ins-xray.sh && ./ins-xray.sh || { echo -e "${RED}[ ERROR ] Instalasi Xray gagal!${NC}"; exit 1; }
elif download_with_retry "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/ins-xray.sh" "ins-xray.sh"; then
    chmod +x ins-xray.sh && ./ins-xray.sh || { echo -e "${RED}[ ERROR ] Instalasi Xray gagal!${NC}"; exit 1; }
else
    echo -e "${RED}[ ERROR ] Gagal mengunduh ins-xray.sh.${NC}"
    exit 1
fi

if [ -s "set-br.sh" ]; then
    chmod +x set-br.sh && ./set-br.sh
elif download_with_retry "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/set-br.sh" "set-br.sh"; then
    chmod +x set-br.sh && ./set-br.sh
else
    echo -e "${RED}[ ERROR ] Gagal mengunduh set-br.sh.${NC}"
    exit 1
fi

# // Download Data
echo -e "${GREEN}Download Data${NC}"
repo_url="https://raw.githubusercontent.com/KedaiVPN/dynamic/main"

download_or_copy() {
    local file_name=$1
    local target_path=$2
    if [ -s "/root/${file_name}" ]; then
        cp -f "/root/${file_name}" "$target_path"
    else
        if ! download_with_retry "${repo_url}/${file_name}" "$target_path"; then
            echo -e "${RED}[ ERROR ] Gagal mengunduh ${file_name} setelah beberapa percobaan.${NC}"
            exit 1
        fi
    fi
}

download_or_copy "add-ws.sh" "/usr/bin/add-ws"
download_or_copy "add-ssws.sh" "/usr/bin/add-ssws"
download_or_copy "add-socks.sh" "/usr/bin/add-socks"
download_or_copy "add-vless.sh" "/usr/bin/add-vless"
download_or_copy "add-tr.sh" "/usr/bin/add-tr"
download_or_copy "add-trgo.sh" "/usr/bin/add-trgo"
download_or_copy "autoreboot.sh" "/usr/bin/autoreboot"
download_or_copy "restart.sh" "/usr/bin/restart"
download_or_copy "tendang.sh" "/usr/bin/tendang"
download_or_copy "clearlog.sh" "/usr/bin/clearlog"
download_or_copy "running.sh" "/usr/bin/running"
download_or_copy "cek-trafik.sh" "/usr/bin/cek-trafik"
download_or_copy "speedtes_cli.py" "/usr/bin/cek-speed"
download_or_copy "cek-bandwidth.sh" "/usr/bin/cek-bandwidth"
download_or_copy "cek-expired.sh" "/usr/bin/cek-expired"
download_or_copy "ram.sh" "/usr/bin/cek-ram"
download_or_copy "limit-speed.sh" "/usr/bin/limit-speed"
download_or_copy "xray-limit.sh" "/usr/bin/xray-limit"
download_or_copy "menu-vless.sh" "/usr/bin/menu-vless"
download_or_copy "menu-vmess.sh" "/usr/bin/menu-vmess"
download_or_copy "menu-socks.sh" "/usr/bin/menu-socks"
download_or_copy "menu-ss.sh" "/usr/bin/menu-ss"
download_or_copy "menu-trojan.sh" "/usr/bin/menu-trojan"
download_or_copy "menu-trgo.sh" "/usr/bin/menu-trgo"
download_or_copy "menu-ssh.sh" "/usr/bin/menu-ssh"
# bckpbot.sh has no source file in this repository; do not request it.
download_or_copy "usernew.sh" "/usr/bin/usernew"
download_or_copy "menu4.sh" "/usr/bin/menu"
download_or_copy "custom-path.sh" "/usr/bin/custom-path"
download_or_copy "slowdns.sh" "/usr/bin/slowdns"
download_or_copy "slowdns-config.sh" "/usr/lib/slowdns-config.sh"
download_or_copy "xray-paths.sh" "/usr/lib/xray-paths.sh"
download_or_copy "xray-account-detail.sh" "/usr/lib/xray-account-detail.sh"
download_or_copy "webmin.sh" "/usr/bin/wbm"
download_or_copy "xp.sh" "/usr/bin/xp"
download_or_copy "update.sh" "/usr/bin/update"
download_or_copy "dns.sh" "/usr/bin/dns"
download_or_copy "netf.sh" "/usr/bin/netf"
download_or_copy "bbr.sh" "/usr/bin/bbr"

download_or_copy "factory-reset.sh" "/usr/local/bin/factory-reset.sh"
chmod +x /usr/local/bin/factory-reset.sh

download_or_copy "install-api.sh" "/usr/bin/install-api"
chmod +x /usr/bin/install-api
if ! /usr/bin/install-api; then
    echo "ERROR: Failed to install API backend!"
    exit 1
fi
chmod +x /usr/bin/add-ws
chmod +x /usr/bin/add-ssws
chmod +x /usr/bin/add-socks
chmod +x /usr/bin/add-vless
chmod +x /usr/bin/add-tr
chmod +x /usr/bin/add-trgo
chmod +x /usr/bin/custom-path
chmod +x /usr/bin/slowdns
chmod 644 /usr/lib/slowdns-config.sh
# SlowDNS is optional. Fresh installs deploy the manager only; the operator
# enables it later from menu SSH → SLOWDNS after DNS delegation is configured.
chmod 644 /usr/lib/xray-paths.sh
chmod 644 /usr/lib/xray-account-detail.sh
chmod +x /usr/bin/usernew
chmod +x /usr/bin/autoreboot
chmod +x /usr/bin/restart
chmod +x /usr/bin/tendang
chmod +x /usr/bin/clearlog
chmod +x /usr/bin/running
chmod +x /usr/bin/cek-trafik
chmod +x /usr/bin/cek-speed
chmod +x /usr/bin/cek-bandwidth
chmod +x /usr/bin/cek-expired
chmod +x /usr/bin/cek-ram
chmod +x /usr/bin/limit-speed
chmod +x /usr/bin/xray-limit
chmod +x /usr/bin/menu-vless
chmod +x /usr/bin/menu-vmess
chmod +x /usr/bin/menu-ss
chmod +x /usr/bin/menu-socks
chmod +x /usr/bin/menu-trojan
chmod +x /usr/bin/menu-trgo
chmod +x /usr/bin/menu-ssh
chmod +x /usr/bin/menu
chmod +x /usr/bin/wbm
chmod +x /usr/bin/xp
chmod +x /usr/bin/update
chmod +x /usr/bin/dns
chmod +x /usr/bin/netf
chmod +x /usr/bin/bbr


# > install gotop
    gotop_link="https://github.com/NevermoreSSH/gotop/releases/download/gotopV4/gotop_v4.2.0_linux_amd64.deb"
    if download_with_retry "$gotop_link" "/tmp/gotop.deb"; then
        dpkg -i /tmp/gotop.deb >/dev/null 2>&1 || true
        rm -f /tmp/gotop.deb
    else
        echo -e "${YELLOW}[ WARN ] Gagal mengunduh gotop, melewati instalasi gotop.${NC}"
    fi


# // Download / Setup License Checker
if [ -f "/root/cek-lisensi.sh" ]; then
    cp -f /root/cek-lisensi.sh /usr/local/bin/cek-lisensi
else
    if ! download_with_retry "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/cek-lisensi.sh" "/usr/local/bin/cek-lisensi"; then
        echo -e "${RED}[ ERROR ] Gagal mengunduh cek-lisensi.sh.${NC}"
        exit 1
    fi
fi
chmod +x /usr/local/bin/cek-lisensi

# > Setup Crontab
echo "*/3 * * * * root /usr/local/bin/cek-lisensi" >> /etc/crontab
echo "0 1 * * * root delete" >> /etc/crontab
echo "0 2 * * * root cleaner" >> /etc/crontab
echo "0 4 * * * root /usr/bin/delete" >> /etc/crontab
echo "0 7 * * * root /usr/bin/cleaner" >> /etc/crontab
if [ ! -f /etc/cron.d/xray-limit ]; then
cat > /etc/cron.d/xray-limit <<-END
*/5 * * * * root /usr/bin/xray-limit
END
fi
cd


cat > /etc/cron.d/xp_otm <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
* * * * * root /usr/bin/xp
END
chmod 644 /etc/cron.d/xp_otm

cat > /etc/cron.d/cl_otm <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
2 1 * * * root /usr/bin/clearlog
END
chmod 644 /etc/cron.d/cl_otm

# Keep Xray bandwidth-lock history for the day, then clear only this history
# at 07:00 local server time. SSH multi-login history is intentionally untouched.
cat > /etc/cron.d/clear-xray-limit <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 7 * * * root : > /root/log-xray-limit.txt
END
chmod 644 /etc/cron.d/clear-xray-limit

cat > /home/re_otm <<-END
7
END

service cron restart >/dev/null 2>&1
service cron reload >/dev/null 2>&1

clear && printf '\033[3J'
cat> /root/.profile << END
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n || true
clear && printf '\033[3J'
menu
END
chmod 644 /root/.profile

if [ -f "/root/log-install.txt" ]; then
rm -fr /root/log-install.txt 
fi
if [ -f "/etc/afak.conf" ]; then
rm -fr /etc/afak.conf 
fi
if [ ! -f "/etc/log-create-user.log" ]; then
echo "Log All Account " > /etc/log-create-user.log
fi
history -c
aureb=$(cat /home/re_otm)
b=11
if [ $aureb -gt $b ]
then
gg="PM"
else
gg="AM"
fi
echo "1.1" >> /home/.ver
curl -sS ifconfig.me > /etc/myipvps
echo " "
echo "====================-[ Kedai SSH TUNNELING ]-===================="
echo ""
echo "------------------------------------------------------------"
echo ""
echo ""
echo "   >>> Service & Port"  | tee -a log-install.txt
echo "   - OpenSSH                 : 22"  | tee -a log-install.txt
echo "   - SSH Websocket           : 80" | tee -a log-install.txt
echo "   - SSH SSL Websocket       : 443" | tee -a log-install.txt
echo "   - Stunnel5                : 447, 777" | tee -a log-install.txt
echo "   - Dropbear                : 109, 143" | tee -a log-install.txt
echo "   - Badvpn                  : 7100-7300" | tee -a log-install.txt
echo "   - Nginx                   : 81" | tee -a log-install.txt
echo "   - XRAY  Vmess TLS         : 443" | tee -a log-install.txt
echo "   - XRAY  Vmess None TLS    : 80" | tee -a log-install.txt
echo "   - XRAY  Vless TLS         : 443" | tee -a log-install.txt
echo "   - XRAY  Vless None TLS    : 80" | tee -a log-install.txt
echo "   - Trojan GRPC             : 443" | tee -a log-install.txt
echo "   - Trojan WS               : 443" | tee -a log-install.txt
echo "   - Trojan GO               : 443" | tee -a log-install.txt
echo "   - Sodosok WS/GRPC         : 443" | tee -a log-install.txt
echo ""  | tee -a log-install.txt
echo "   >>> Server Information & Other Features"  | tee -a log-install.txt
echo "   - Timezone                : Asia/Jakarta (GMT +7)"  | tee -a log-install.txt
echo "   - Fail2Ban                : [ON]"  | tee -a log-install.txt
echo "   - Dflate                  : [ON]"  | tee -a log-install.txt
echo "   - IPtables                : [ON]"  | tee -a log-install.txt
echo "   - Auto-Reboot             : [ON]"  | tee -a log-install.txt
echo "   - IPv6                    : [OFF]"  | tee -a log-install.txt
echo "   - Autoreboot Off          : $aureb:00 $gg GMT + 7" | tee -a log-install.txt
echo "   - Autobackup Data" | tee -a log-install.txt
echo "   - AutoKill Multi Login User" | tee -a log-install.txt
echo "   - Auto Delete Expired Account" | tee -a log-install.txt
echo "   - Fully automatic script" | tee -a log-install.txt
echo "   - VPS settings" | tee -a log-install.txt
echo "   - Admin Control" | tee -a log-install.txt
echo "   - Change port" | tee -a log-install.txt
echo "   - Restore Data" | tee -a log-install.txt
echo "   - Full Orders For Various Services" | tee -a log-install.txt
echo ""
echo ""
echo "------------------------------------------------------------"
echo ""
echo "===============-[ Script Mod By KEDAI SSH TUNNELING ]-==============="
echo -e ""
echo ""
echo "" | tee -a log-install.txt
# // Install Monitoring service di akhir (idempotent, aman untuk server baru/lama)
echo -e "\033[0;32m[INFO]\033[0m Menjalankan installer VPS Monitor (SSE)..."
if [ -s "monitor.sh" ]; then
    chmod +x monitor.sh && ./monitor.sh
elif download_with_retry "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/monitor.sh" "monitor.sh"; then
    chmod +x monitor.sh && ./monitor.sh
else
    echo -e "${YELLOW}[ WARN ] Gagal mengunduh monitor.sh, lewati instalasi VPS Monitor.${NC}"
fi

rm -fr /root/weleh.sh 
rm -fr /root/vnstat.sh 
rm -fr /root/ssh-vpn.sh
rm -fr /root/udp-custom.sh
rm -fr /root/ins-xray.sh
rm -fr /root/monitor.sh
rm -fr /root/setup.sh
rm -fr /root/domain

history -c

# Mode manual tetap menunggu Enter seperti sebelumnya.
# Mode AUTO_INSTALL tidak boleh menggantung di prompt; reboot terjadwal agar
# SSH stream dapat selesai (exit 0) dan daemon menerima status sukses.
if [[ -n "$AUTO_INSTALL" ]]; then
    echo -e "[ \033[0;32mOKEY\033[0m ] Instalasi otomatis selesai. Reboot dalam 10 detik."
    nohup bash -c 'sleep 10; reboot' >/dev/null 2>&1 &
    exit 0
else
    read -p "$( echo -e "Press ${orange}[ ${NC}${green}Enter${NC} ${CYAN}]${NC} For Reboot") "
    reboot
fi
