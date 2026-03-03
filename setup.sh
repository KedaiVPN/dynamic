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

# // License Verification
function verify_license() {
    echo -e "\033[0;33m[ INFO ]\033[0m Sedang memverifikasi lisensi instalasi Anda..."
    local SERVER_IP
    SERVER_IP=$(curl -sS ipv4.icanhazip.com)
    if [ -z "$SERVER_IP" ]; then
        echo -e "\033[0;31m[ ERROR ]\033[0m Gagal mengambil IP server. Periksa koneksi internet Anda."
        exit 1
    fi

    local license_data
    license_data=$(curl -s "https://raw.githubusercontent.com/kedaivpn/izin/main/allowed")
    if [ $? -ne 0 ] || [ -z "$license_data" ]; then
        echo -e "\033[0;31m[ ERROR ]\033[0m Gagal terhubung ke server lisensi. Mohon periksa koneksi internet Anda."
        exit 1
    fi

    local license_entry
    license_entry=$(echo "$license_data" | grep -w "$SERVER_IP")

    if [ -z "$license_entry" ]; then
        echo -e "────────────────────────────────────────────"
        echo -e " ⚠️       AKSES DI TOLAK         ⚠️"
        echo -e "────────────────────────────────────────────"
        echo -e "        ❌  SCRIPT LOCKED ❌"
        echo -e "  🔒 Your VPS  Has been Banned"
        echo -e "  ⚠️  IP Tidak Terdaftar ⚠️"
        echo -e "  IP Anda: $SERVER_IP"
        echo -e "  💡 Beli izin resmi hanya dari Admin!"
        echo -e "  📞 Contact Admin:"
        echo -e "  🌍 Telegram: https://t.me/Kedai_vpn"
        echo -e "  📱 WhatsApp: https://wa.me/6287777694482"
        echo -e "────────────────────────────────────────────"
        exit 1
    fi

    # Variables that need to be accessed globally outside the function
    client_name=$(echo "$license_entry" | awk '{print $1}')
    expiry_date_str=$(echo "$license_entry" | awk '{print $2}')

    local expiry_timestamp
    expiry_timestamp=$(date -d "$expiry_date_str" +%s)
    local current_timestamp
    current_timestamp=$(date +%s)

    if [ "$expiry_timestamp" -le "$current_timestamp" ]; then
        echo -e "────────────────────────────────────────────"
        echo -e " ⚠️       AKSES DI TOLAK         ⚠️"
        echo -e "────────────────────────────────────────────"
        echo -e "        ❌  SCRIPT LOCKED ❌"
        echo -e "  🔒 Your VPS  Has been Banned"
        echo -e "  ⚠️  Masa Aktif Sudah Habis ⚠️"
        echo -e "  Expired: $expiry_date_str"
        echo -e "  💡 Beli izin resmi hanya dari Admin!"
        echo -e "  📞 Contact Admin:"
        echo -e "  🌍 Telegram: https://t.me/Kedai_vpn"
        echo -e "  📱 WhatsApp: https://wa.me/6287777694482"
        echo -e "────────────────────────────────────────────"
        exit 1
    fi
    
    local remaining_days
    remaining_days=$(((expiry_timestamp - current_timestamp) / 86400))
    echo -e "\033[0;32m[ OKEY ]\033[0m Lisensi terverifikasi! (Client: $client_name, Sisa: $remaining_days hari)"
    sleep 2
    
    mkdir -p /etc/xray
    echo "$client_name" > /etc/xray/license_client
    echo "$expiry_date_str" > /etc/xray/license_exp
}

verify_license

# // Cek old script
if [[ -r /etc/xray/domain ]]; then
echo -e "[ \033[0;33mINFO\033[0m ] Having Script Detected !"
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
clear && printf '\033[3J'
fi

echo -e "\033[0;32m[ INFO ]\033[0m Cleaning up old directories and packages before starting..."
# // Remove Old Directories first so we don't wipe our newly inputted domain
rm -fr /usr/local/bin/xray
rm -fr /usr/local/bin/stunnel
rm -fr /usr/local/bin/stunnel5
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
read -rp "Masukkan Domain Anda: " domain
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
apt-get --reinstall --fix-missing install -y libreadline-dev zlib1g-dev libssl-dev python3 screen curl jq bzip2 gzip coreutils rsyslog iftop htop zip unzip net-tools sed gnupg gnupg1 bc sudo apt-transport-https build-essential dirmngr libxml-parser-perl neofetch screenfetch git lsof openssl easy-rsa fail2ban tmux vnstat dropbear libsqlite3-dev socat cron bash-completion ntpdate xz-utils sudo apt-transport-https gnupg2 gnupg1 dnsutils lsb-release chrony
gem install lolcat

# // Update & Upgrade
apt update -y
apt upgrade -y
apt dist-upgrade -y

# // Clear
clear && printf '\033[3J'
clear && printf '\033[3J' && clear && printf '\033[3J' && clear && printf '\033[3J'
clear && printf '\033[3J';clear && printf '\033[3J';clear && printf '\033[3J'

echo -e "[ \033[0;32mINFO\033[0m ] Starting renew gen-ssl... " 
sleep 2
mkdir -p /root/.acme.sh
curl https://acme-install.netlify.app/acme.sh -o /root/.acme.sh/acme.sh
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

#install vnstat
echo -e "$white\033[0;34m┌─────────────────────────────────────────┐${NC}"
echo -e " \E[41;1;39m           ⇱ Install vnStat ⇲            \E[0m$NC"
echo -e "$white\033[0;34m└─────────────────────────────────────────┘${NC}"
sleep 1 
wget -q https://raw.githubusercontent.com/KedaiVPN/dynamic/main/vnstat.sh && chmod +x vnstat.sh && ./vnstat.sh
#install ssh-vpn
echo -e "$white\033[0;34m┌─────────────────────────────────────────┐${NC}"
echo -e " \E[41;1;39m          ⇱ Install SSH / WS ⇲           \E[0m$NC"
echo -e "$white\033[0;34m└─────────────────────────────────────────┘${NC}"
sleep 1
wget -q https://raw.githubusercontent.com/KedaiVPN/dynamic/main/ssh-vpn.sh && chmod +x ssh-vpn.sh && ./ssh-vpn.sh
#install ins-xray
echo -e "$white\033[0;34m┌─────────────────────────────────────────┐${NC}"
echo -e " \E[41;1;39m            ⇱ Install Xray ⇲             \E[0m$NC"
echo -e "$white\033[0;34m└─────────────────────────────────────────┘${NC}"
sleep 1 
wget -q https://raw.githubusercontent.com/KedaiVPN/dynamic/main/ins-xray.sh && chmod +x ins-xray.sh && ./ins-xray.sh
wget -q https://raw.githubusercontent.com/KedaiVPN/dynamic/main/set-br.sh && chmod +x set-br.sh && ./set-br.sh

# // Download Data
echo -e "${GREEN}Download Data${NC}"
wget -q -O /usr/bin/add-ws "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/add-ws.sh"
wget -q -O /usr/bin/add-ssws "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/add-ssws.sh"
wget -q -O /usr/bin/add-socks "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/add-socks.sh"
wget -q -O /usr/bin/add-vless "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/add-vless.sh"
wget -q -O /usr/bin/add-tr "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/add-tr.sh"
wget -q -O /usr/bin/add-trgo "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/add-trgo.sh"
wget -q -O /usr/bin/autoreboot "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/autoreboot.sh"
wget -q -O /usr/bin/restart "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/restart.sh"
wget -q -O /usr/bin/tendang "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/tendang.sh"
wget -q -O /usr/bin/clearlog "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/clearlog.sh"
wget -q -O /usr/bin/running "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/running.sh"
wget -q -O /usr/bin/cek-trafik "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/cek-trafik.sh"
wget -q -O /usr/bin/cek-speed "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/speedtes_cli.py"
wget -q -O /usr/bin/cek-bandwidth "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/cek-bandwidth.sh"
wget -q -O /usr/bin/cek-expired "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/cek-expired.sh"
wget -q -O /usr/bin/cek-ram "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/ram.sh"
wget -q -O /usr/bin/limit-speed "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/limit-speed.sh"
wget -q -O /usr/bin/xray-limit "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/xray-limit.sh"
wget -q -O /usr/bin/menu-vless "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/menu-vless.sh"
wget -q -O /usr/bin/menu-vmess "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/menu-vmess.sh"
wget -q -O /usr/bin/menu-socks "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/menu-socks.sh"
wget -q -O /usr/bin/menu-ss "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/menu-ss.sh"
wget -q -O /usr/bin/menu-trojan "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/menu-trojan.sh"
wget -q -O /usr/bin/menu-trgo "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/menu-trgo.sh"
wget -q -O /usr/bin/menu-ssh "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/menu-ssh.sh"
wget -q -O /usr/bin/bckp "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/bckpbot.sh"
wget -q -O /usr/bin/usernew "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/usernew.sh"
wget -q -O /usr/bin/menu "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/menu4.sh"
wget -q -O /usr/bin/wbm "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/webmin.sh"
wget -q -O /usr/bin/xp "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/xp.sh"
wget -q -O /usr/bin/update "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/update.sh"
wget -q -O /usr/bin/dns "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/dns.sh"
wget -q -O /usr/bin/netf "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/netf.sh"
wget -q -O /usr/bin/bbr "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/bbr.sh"
wget -q -O /usr/bin/install-api "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/install-api.sh" && chmod +x /usr/bin/install-api && /usr/bin/install-api
chmod +x /usr/bin/add-ws
chmod +x /usr/bin/add-ssws
chmod +x /usr/bin/add-socks
chmod +x /usr/bin/add-vless
chmod +x /usr/bin/add-tr
chmod +x /usr/bin/add-trgo
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
chmod +x /usr/bin/bckp
chmod +x /usr/bin/wbm
chmod +x /usr/bin/xp
chmod +x /usr/bin/update
chmod +x /usr/bin/dns
chmod +x /usr/bin/netf
chmod +x /usr/bin/bbr


# > install gotop
    gotop_latest="$(curl -s https://api.github.com/repos/NevermoreSSH/gotop/releases | grep tag_name | sed -E 's/.*"v(.*)".*/\1/' | head -n 1)"
    gotop_link="https://github.com/NevermoreSSH/gotop/releases/download/gotopV4/gotop_v4.2.0_linux_amd64.deb"
    curl -sL "$gotop_link" -o /tmp/gotop.deb
    dpkg -i /tmp/gotop.deb >/dev/null 2>&1


# // Download / Setup License Checker
wget -q -O /usr/local/bin/cek-lisensi "https://raw.githubusercontent.com/KedaiVPN/dynamic/main/cek-lisensi.sh"
chmod +x /usr/local/bin/cek-lisensi

# > Setup Crontab
echo "*/10 * * * * root /usr/local/bin/cek-lisensi" >> /etc/crontab
echo "0 1 * * * root delete" >> /etc/crontab
echo "0 2 * * * root cleaner" >> /etc/crontab
echo "0 4 * * * root /usr/bin/delete" >> /etc/crontab
echo "0 7 * * * root /usr/bin/cleaner" >> /etc/crontab
echo "0 5 * * * root reboot" >> /etc/crontab
echo "0 6 * * * root backup" >> /etc/crontab
echo "0 23 * * * root backup" >> /etc/crontab
echo "5 23 * * * root /usr/bin/backup" >> /etc/crontab
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

cat > /etc/cron.d/cl_otm <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
2 1 * * * root /usr/bin/clearlog
END

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
echo "====================-[ NevermoreSSH TUNNELING ]-===================="
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
echo "===============-[ Script Mod By NEVERMORESSH TUNNELING ]-==============="
echo -e ""
echo ""
echo "" | tee -a log-install.txt
rm -fr /root/weleh.sh 
rm -fr /root/vnstat.sh 
rm -fr /root/ssh-vpn.sh
rm -fr /root/ins-xray.sh
rm -fr /root/setup.sh
rm -fr /root/domain
history -c

read -p "$( echo -e "Press ${orange}[ ${NC}${green}Enter${NC} ${CYAN}]${NC} For Reboot") "
reboot
