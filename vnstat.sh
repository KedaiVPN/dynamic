#!/bin/bash
BIBlack='\033[1;90m'      # Black
BIRed='\033[1;91m'        # Red
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow
BIBlue='\033[1;94m'       # Blue
BIPurple='\033[1;95m'     # Purple
BICyan='\033[1;96m'       # Cyan
BIWhite='\033[1;97m'      # White
UWhite='\033[4;37m'       # White
On_IPurple='\033[0;105m'  #
On_IRed='\033[0;101m'
IBlack='\033[0;90m'       # Black
IRed='\033[0;91m'         # Red
IGreen='\033[0;92m'       # Green
IYellow='\033[0;93m'      # Yellow
IBlue='\033[0;94m'        # Blue
IPurple='\033[0;95m'      # Purple
ICyan='\033[0;96m'        # Cyan
IWhite='\033[0;97m'       # White
NC='\e[0m'

# // Export Color & Information
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export PURPLE='\033[0;35m'
export CYAN='\033[0;36m'
export LIGHT='\033[0;37m'
export NC='\033[0m'

# // Export Banner Status Information
export EROR="[${RED} EROR ${NC}]"
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
export Server_Port="443"
export Server_IP="underfined"
export Script_Mode="Stable"
export Auther=".geovpn"

# // Root Checking
if [ "${EUID}" -ne 0 ]; then
		echo -e "${EROR} Please Run This Script As Root User !"
		exit 1
fi

# // License Checking
if [ -f /usr/local/bin/cek-lisensi ]; then
    /usr/local/bin/cek-lisensi --check-only || exit 1
fi


# // Exporting IP Address
export IP=$( curl -s https://ipinfo.io/ip/ )
IP=$(curl -s ipinfo.io/ip )
IP=$(curl -sS ipv4.icanhazip.com)
IP=$(curl -sS ifconfig.me )

# // Exporting Network Interface
export NETWORK_IFACE="$(ip route show to default | awk '{print $5}')"



red='\e[1;31m'
green='\e[1;32m'
yell='\e[1;33m'
NC='\e[0m'
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

clear && printf '\033[3J'
if [[ -e /etc/debian_version ]]; then
	source /etc/os-release
	OS=$ID # debian or ubuntu
elif [[ -e /etc/centos-release ]]; then
	source /etc/os-release
	OS=centos
fi

echo "Installing vnStat"
echo "Progress..."
sleep 2

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

apt_with_retry() {
    local max_attempts=3
    local attempt=1
    while [ "$attempt" -le "$max_attempts" ]; do
        if DEBIAN_FRONTEND=noninteractive apt-get \
            -o DPkg::Lock::Timeout=120 \
            -o Acquire::Retries=5 \
            -o Acquire::http::Timeout=30 \
            -o Acquire::https::Timeout=30 \
            "$@"; then
            return 0
        fi
        DEBIAN_FRONTEND=noninteractive dpkg --configure -a >/dev/null 2>&1 || true
        DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 update -y >/dev/null 2>&1 || true
        attempt=$((attempt + 1))
        sleep 2
    done
    return 1
}

if ! command -v gcc >/dev/null 2>&1 || ! command -v make >/dev/null 2>&1 || [ ! -f /usr/include/sqlite3.h ]; then
    apt_with_retry update -y >/dev/null 2>&1 || true
    apt_with_retry install -y build-essential libsqlite3-dev >/dev/null 2>&1 || true
fi

/etc/init.d/vnstat restart >/dev/null 2>&1 || true
vnstat_downloaded=0
for vn_attempt in 1 2 3 4 5; do
    rm -f vnstat-2.6.tar.gz
    if download_with_retry "https://github.com/NevermoreSSH/vnstat/releases/download/vnstat/vnstat-2.6.tar.gz" "vnstat-2.6.tar.gz" 3 2 && tar -tzf vnstat-2.6.tar.gz >/dev/null 2>&1; then
        vnstat_downloaded=1
        break
    fi
    sleep 2
done
if [ "$vnstat_downloaded" -eq 1 ]; then
    tar zxvf vnstat-2.6.tar.gz
    cd vnstat-2.6
    if ./configure --prefix=/usr --sysconfdir=/etc >/dev/null 2>&1 && make >/dev/null 2>&1 && make install >/dev/null 2>&1; then
        cd
        vnstat -u -i "$NET" >/dev/null 2>&1 || true
        sed -i 's/Interface "'""eth0""'"/Interface "'""$NET""'"/g' /etc/vnstat.conf 2>/dev/null || true
        chown vnstat:vnstat /var/lib/vnstat -R 2>/dev/null || true
    else
        cd
        apt_with_retry update -y >/dev/null 2>&1 || true
        apt_with_retry install -y vnstat || true
    fi
else
    apt_with_retry update -y >/dev/null 2>&1 || true
    apt_with_retry install -y vnstat || true
fi
if ! command -v vnstat >/dev/null 2>&1; then
    echo "Gagal menginstall vnstat"
    exit 1
fi
systemctl enable vnstat >/dev/null 2>&1 || true
/etc/init.d/vnstat restart >/dev/null 2>&1 || systemctl restart vnstat >/dev/null 2>&1 || true
rm -f /root/vnstat-2.6.tar.gz >/dev/null 2>&1
rm -rf /root/vnstat-2.6 >/dev/null 2>&1

yellow() { echo -e "\\033[33;1m${*}\\033[0m"; }
yellow "vnStat successfully installed..."
sleep 3
clear && printf '\033[3J'
