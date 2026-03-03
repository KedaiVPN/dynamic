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
m="\033[0;1;36m"
y="\033[0;1;37m"
yy="\033[0;1;32m"
yl="\033[0;1;33m"
wh="\033[0m"
## Foreground
DEFBOLD='\e[39;1m'
RB='\e[31;1m'
GB='\e[32;1m'
YB='\e[33;1m'
BB='\e[34;1m'
MB='\e[35;1m'
CB='\e[35;1m'
WB='\e[37;1m'

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
export Server_URL="raw.githubusercontent.com/NevermoreSSH/Blueblue/main/test"
export Server1_URL="raw.githubusercontent.com/NevermoreSSH/Blueblue/main/limit"
export Server_Port="443"
export Server_IP="underfined"
export Script_Mode="Stable"
export Auther=".geovpn"

# // Root Checking
if [ "${EUID}" -ne 0 ]; then
		echo -e "${EROR} Please Run This Script As Root User !"
		exit 1
fi

# // Exporting IP Address
export IP=$( curl -s https://ipinfo.io/ip/ )

# // Exporting Network Interface
export NETWORK_IFACE="$(ip route show to default | awk '{print $5}')"

# // Clear
clear && printf '\033[3J'
clear && printf '\033[3J' && clear && printf '\033[3J' && clear && printf '\033[3J'
clear && printf '\033[3J';clear && printf '\033[3J';clear && printf '\033[3J'
cek=$(service ssh status | grep active | cut -d ' ' -f5)
if [ "$cek" = "active" ]; then
stat=-f5
else
stat=-f7
fi
ssh=$(service ssh status | grep active | cut -d ' ' $stat)
if [ "$ssh" = "active" ]; then
ressh="${BIGreen}ON${NC}"
else
ressh="${red}OFF${NC}"
fi
sshstunel=$(service stunnel5 status | grep active | cut -d ' ' $stat)
if [ "$sshstunel" = "active" ]; then
resst="${BIGreen}ON${NC}"
else
resst="${red}OFF${NC}"
fi
sshws=$(service ws-stunnel status | grep active | cut -d ' ' $stat)
if [ "$sshws" = "active" ]; then
ressshws="${BIGreen}ON${NC}"
else
ressshws="${red}OFF${NC}"
fi
ngx=$(service nginx status | grep active | cut -d ' ' $stat)
if [ "$ngx" = "active" ]; then
resngx="${BIGreen}ON${NC}"
else
resngx="${red}OFF${NC}"
fi
dbr=$(service dropbear status | grep active | cut -d ' ' $stat)
if [ "$dbr" = "active" ]; then
resdbr="${BIGreen}ON${NC}"
else
resdbr="${red}OFF${NC}"
fi
v2r=$(service xray status | grep active | cut -d ' ' $stat)
if [ "$v2r" = "active" ]; then
resv2r="${BIGreen}ON${NC}"
else
resv2r="${red}OFF${NC}"
fi
hpx=$(service haproxy status | grep active | cut -d ' ' $stat)
if [ "$hpx" = "active" ]; then
reshpx="${BIGreen}ON${NC}"
else
reshpx="${red}OFF${NC}"
fi
function addhost(){
clear && printf '\033[3J'
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
read -rp "Domain/Host: " -e host
echo ""
if [ -z $host ]; then
echo "????"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -n 1 -s -r -p "Press any key to back on menu"
setting-menu
else
rm -fr /etc/xray/domain
echo "IP=$host" > /var/lib/scrz-prem/ipvps.conf
echo $host > /etc/xray/domain
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "Dont forget to renew gen-ssl"
echo ""
read -n 1 -s -r -p "Press any key to back on menu"
menu
fi
}
function genssl(){
clear && printf '\033[3J'
systemctl stop nginx
systemctl stop xray
domain=$(cat /var/lib/scrz-prem/ipvps.conf | cut -d'=' -f2)
Cek=$(lsof -i:80 | cut -d' ' -f1 | awk 'NR==2 {print $1}')
if [[ ! -z "$Cek" ]]; then
sleep 1
echo -e "[ ${red}WARNING${NC} ] Detected port 80 used by $Cek " 
systemctl stop $Cek
sleep 2
echo -e "[ ${green}INFO${NC} ] Processing to stop $Cek " 
sleep 1
fi
echo -e "[ ${green}INFO${NC} ] Starting renew gen-ssl... " 
sleep 2
/root/.acme.sh/acme.sh --upgrade
/root/.acme.sh/acme.sh --upgrade --auto-upgrade
/root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
/root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc

cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/xray/xray.pem
chmod 644 /etc/xray/xray.pem

echo -e "[ ${green}INFO${NC} ] Renew gen-ssl done... " 
sleep 2
echo -e "[ ${green}INFO${NC} ] Starting service $Cek " 
sleep 2
echo $domain > /etc/xray/domain
systemctl start nginx
systemctl start xray
systemctl restart haproxy
echo -e "[ ${green}INFO${NC} ] All finished... " 
sleep 0.5
echo ""
read -n 1 -s -r -p "Press any key to back on menu"
menu
}

function autobackup(){
clear && printf '\033[3J'
echo -e "${BICyan} ┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BICyan} │                  ${BIWhite}${UWhite}AUTO BACKUP DATA${NC}"
echo -e "${BICyan} └────────────────────────────────────────────────────────────┘${NC}"
echo -e " ${BIYellow}Masukkan angka dalam hitungan jam untuk menjalankan auto backup.${NC}"
echo -e " ${BIWhite}Contoh:${NC}"
echo -e "  - Ketik ${BIGreen}1${NC} untuk backup setiap 1 jam."
echo -e "  - Ketik ${BIGreen}12${NC} untuk backup setiap 12 jam."
echo -e "  - Ketik ${BIRed}0${NC} untuk mematikan auto backup."
echo -e " ${BICyan}────────────────────────────────────────────────────────────${NC}"
read -rp " Masukkan pilihan (Jam) : " input_jam

if [[ ! $input_jam =~ ^[0-9]+$ ]]; then
    echo -e " ${BIRed}[ ERROR ] Input harus berupa angka!${NC}"
    sleep 2
    menu_backup_restore
    return
fi

if [[ $input_jam -eq 0 ]]; then
    rm -f /etc/cron.d/autobackup
    service cron restart > /dev/null 2>&1
    service cron reload > /dev/null 2>&1
    echo -e " ${BIGreen}[ INFO ] Auto Backup berhasil DIMATIKAN.${NC}"
else
    cat > /etc/cron.d/autobackup <<-END
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 */$input_jam * * * root /usr/bin/backup > /dev/null 2>&1
END
    service cron restart > /dev/null 2>&1
    service cron reload > /dev/null 2>&1
    echo -e " ${BIGreen}[ INFO ] Auto Backup berhasil DISET setiap $input_jam Jam.${NC}"
fi
echo ""
read -n 1 -s -r -p "Tekan tombol apapun untuk kembali ke menu"
menu_backup_restore
}

function menu_backup_restore(){
clear && printf '\033[3J'
echo -e "${BICyan} ┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BICyan} │                  ${BIWhite}${UWhite}BACKUP / RESTORE${NC}"
echo -e "${BICyan} │"
echo -e "     ${BICyan}[${BIWhite}01${BICyan}] BACKUP DATA ${BICyan}${BIYellow}${BICyan}${NC}"
echo -e "     ${BICyan}[${BIWhite}02${BICyan}] RESTORE DATA ${BICyan}${BIYellow}${BICyan}${NC}"
echo -e "     ${BICyan}[${BIWhite}03${BICyan}] AUTO BACKUP ${BICyan}${BIYellow}${BICyan}${NC}"
echo -e "     ${BICyan}[${BIWhite}x ${BICyan}] BACK TO MENU ${BICyan}${BIYellow}${BICyan}${NC}"
echo -e "${BICyan} └────────────────────────────────────────────────────────────┘${NC}"
echo
read -p " Select menu : " opt_br
case $opt_br in
1) clear && printf '\033[3J' ; backup ;;
2) clear && printf '\033[3J' ; restore ;;
3) clear && printf '\033[3J' ; autobackup ;;
x) menu ;;
*) menu ;;
esac
}

function change_ws_response() {
    clear && printf '\033[3J'
    echo -e "${BICyan} ┌────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BICyan} │                ${BIWhite}${UWhite}EDIT WS-STUNNEL RESPONSE${NC}                    ${BICyan}│${NC}"
    echo -e "${BICyan} └────────────────────────────────────────────────────────────┘${NC}"
    echo -e ""

    # Check current response
    local current_text="CONNECTED TO PREMIUM SERVER"
    local current_color="cyan"

    if [[ -f /etc/ws-stunnel-response ]]; then
        current_text=$(sed -n '1p' /etc/ws-stunnel-response)
        current_color=$(sed -n '2p' /etc/ws-stunnel-response)
    fi

    echo -e " Current Text : ${BIWhite}$current_text${NC}"
    echo -e " Current Color: ${BIWhite}$current_color${NC}"
    echo -e ""

    read -p " Enter new text [Press Enter to keep current]: " new_text
    if [[ -z "$new_text" ]]; then
        new_text="$current_text"
    fi

    echo -e ""
    echo -e " Supported Colors: red, green, blue, cyan, yellow, magenta, white, black, etc."
    read -p " Enter new color [Press Enter to keep current]: " new_color
    if [[ -z "$new_color" ]]; then
        new_color="$current_color"
    fi

    # Save to file
    echo "$new_text" > /etc/ws-stunnel-response
    echo "$new_color" >> /etc/ws-stunnel-response

    echo -e ""
    echo -e " ${BGreen}Successfully updated response!${NC}"
    echo -e " ${BWhite}Restarting ws-stunnel service...${NC}"
    systemctl restart ws-stunnel
    sleep 2

    echo -e ""
    read -n 1 -s -r -p " Press any key to return to features menu..."
    menu_features
}

function menu_features(){
clear && printf '\033[3J'
echo -e "${BICyan} ┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BICyan} │                  ${BIWhite}${UWhite}ADDITIONAL FEATURES${NC}"
echo -e "${BICyan} │"
echo -e "     ${BICyan}[${BIWhite}01${BICyan}] ADD HOST/DOMAIN      ${BICyan}[${BIWhite}13${BICyan}] WEBMIN${NC}"
echo -e "     ${BICyan}[${BIWhite}02${BICyan}] RENEW CERT           ${BICyan}[${BIWhite}14${BICyan}] INFO SCRIPT${NC}"
echo -e "     ${BICyan}[${BIWhite}03${BICyan}] EDIT BANNER          ${BICyan}[${BIWhite}15${BICyan}] CLEAR LOG${NC}"
echo -e "     ${BICyan}[${BIWhite}04${BICyan}] CHECK BANDWIDTH      ${BICyan}[${BIWhite}16${BICyan}] DNS CHANGER${NC}"
echo -e "     ${BICyan}[${BIWhite}05${BICyan}] SPEEDTEST            ${BICyan}[${BIWhite}17${BICyan}] NETFLIX CHECKER${NC}"
echo -e "     ${BICyan}[${BIWhite}06${BICyan}] LIMIT SPEED          ${BICyan}[${BIWhite}18${BICyan}] TENDANG${NC}"
echo -e "     ${BICyan}[${BIWhite}07${BICyan}] AUTO REBOOT          ${BICyan}[${BIWhite}19${BICyan}] XRAY-CORE MENU${NC}"
echo -e "     ${BICyan}[${BIWhite}08${BICyan}] REBOOT               ${BICyan}[${BIWhite}20${BICyan}] INSTALL BBRPLUS${NC}"
echo -e "     ${BICyan}[${BIWhite}09${BICyan}] RESTART              ${BICyan}[${BIWhite}21${BICyan}] SWAPRAM MENU${NC}"
echo -e "     ${BICyan}[${BIWhite}10${BICyan}] GOTOP (RAM MONITOR)  ${BICyan}[${BIWhite}22${BICyan}] INSTALL BOT TELE${NC}"
echo -e "     ${BICyan}[${BIWhite}11${BICyan}] GENERATE API KEY     ${BICyan}[${BIWhite}x${BICyan}] BACK TO MENU${NC}"
echo -e "     ${BICyan}[${BIWhite}12${BICyan}] EDIT WS RESPONSE${NC}"
echo -e "${BICyan} └────────────────────────────────────────────────────────────┘${NC}"
echo
read -p " Select menu : " opt_feat
case $opt_feat in
1) clear && printf '\033[3J' ; addhost ;;
2) clear && printf '\033[3J' ; genssl ;;
3) clear && printf '\033[3J' ; nano /etc/issue.net ;;
4) clear && printf '\033[3J' ; cek-bandwidth ;;
5) clear && printf '\033[3J' ; cek-speed ;;
6) clear && printf '\033[3J' ; limit-speed ;;
7) clear && printf '\033[3J' ; autoreboot ;;
8) clear && printf '\033[3J' ; reboot ;;
9) clear && printf '\033[3J' ; restart ;;
10) clear && printf '\033[3J' ; gotop ;;
11) clear && printf '\033[3J' ; /usr/local/bin/api-modules/api-bot-manager.sh ;;
12) clear && printf '\033[3J' ; change_ws_response ;;
13) clear && printf '\033[3J' ; wbm ;;
14) clear && printf '\033[3J' ; cat /root/log-install.txt ;;
15) clear && printf '\033[3J' ; clearlog ;;
16) clear && printf '\033[3J' ; dns ;;
17) clear && printf '\033[3J' ; netf ;;
18) clear && printf '\033[3J' ; tendang ;;
19) clear && printf '\033[3J' ; wget -q -O /usr/bin/xraychanger "https://raw.githubusercontent.com/NevermoreSSH/Xcore-custompath/main/xraychanger.sh" && chmod +x /usr/bin/xraychanger && xraychanger ;;
20) clear && printf '\033[3J' ; bbr ;;
21) clear && printf '\033[3J' ; wget -q -O /usr/bin/swapram "https://raw.githubusercontent.com/NevermoreSSH/swapram/main/swapram.sh" && chmod +x /usr/bin/swapram && swapram ;;
22) clear && printf '\033[3J' ; /usr/local/bin/api-modules/api-auth-gen.sh ;;
x) menu ;;
*) menu ;;
esac
}

export sem=$( curl -s https://raw.githubusercontent.com/kedaivpn/dynamic/main/test/versions)
export pak=$( cat /home/.ver)
IPVPS=$(curl -s ipinfo.io/ip )
IPVPS=$(curl -sS ipv4.icanhazip.com)
IPVPS=$(curl -sS ifconfig.me )
ISPVPS=$( curl -s ipinfo.io/org )
daily_usage=$(vnstat -d --oneline | awk -F\; '{print $6}' | sed 's/ //')
monthly_usage=$(vnstat -m --oneline | awk -F\; '{print $11}' | sed 's/ //')
ram_used=$(free -m | grep Mem: | awk '{print $3}')
total_ram=$(free -m | grep Mem: | awk '{print $2}')
ram_usage=$(echo "scale=2; ($ram_used / $total_ram) * 100" | bc | cut -d. -f1)
# OS Uptime
uptime="$(uptime -p | cut -d " " -f 2-10)"
# TOTAL ACC XRAYS WS & XTLS
vmess=$(grep -c -E "^#vmsg $user" "/etc/xray/config.json")
vless=$(grep -c -E "^#vlsg $user" "/etc/xray/config.json")
tr=$(grep -c -E "^#trg $user" "/etc/xray/config.json")
ss=$(grep -c -E "^#ssg $user" "/etc/xray/config.json")
ssh="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)"
# Getting CPU Information
cpu_usage1="$(ps aux | awk 'BEGIN {sum=0} {sum+=$3}; END {print sum}')"
cpu_usage="$((${cpu_usage1/\.*/} / ${corediilik:-1}))"
cpu_usage+="%"
cname=$(awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo)
cores=$(awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo)
freq=$(awk -F: ' /cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo)

# Getting License Information
if [ -f /etc/xray/license_client ]; then
    client_name=$(cat /etc/xray/license_client)
    exp_date=$(cat /etc/xray/license_exp)
    d1=$(date -d "$exp_date" +%s)
    d2=$(date -d "today" +%s)
    certifacate=$(((d1 - d2) / 86400))
    exp_days="${certifacate} days"
else
    client_name="Unknown"
    exp_days="Unknown"
fi

clear && printf '\033[3J'
echo -e "${BICyan} ┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "${BICyan} │                  ${BIWhite}${UWhite}Server Informations${NC}"         
echo -e "${BICyan} │"                                                                      
echo -e "${BICyan} │  ${BICyan}OS Linux        :  "$(hostnamectl | grep "Operating System" | cut -d ' ' -f5-)  
echo -e "${BICyan} │  ${BICyan}Kernel          :  ${BICyan}$(uname -r)${NC}"  
echo -e "${BICyan} │  ${BICyan}CPU Name        : ${BIWhite}$cname${NC}"
echo -e "${BICyan} │  ${BICyan}CPU Info        :  ${BIWhite}$cores Cores @ $freq MHz (${cpu_usage}) ${NC}"
echo -e "${BICyan} │  ${BICyan}Total RAM       :  ${BIWhite}${ram_used}MB / ${total_ram}MB (${ram_usage}%) ${NC}" 
echo -e "${BICyan} │  ${BICyan}System Uptime   :  ${BIWhite}$uptime${NC}"
echo -e "${BICyan} │  ${BICyan}Current Domain  :  ${BIWhite}$(cat /etc/xray/domain)${NC}" 
echo -e "${BICyan} │  ${BICyan}IP-VPS          :  ${BIWhite}$IPVPS${NC}"                  
#echo -e "${BICyan} │  ${BICyan}ISP-VPS         :  ${BIWhite}$ISPVPS${NC}"  
echo -e "${BICyan} │  ${BICyan}Client          :  ${BIWhite}$client_name${NC}"
echo -e "${BICyan} │  ${BICyan}Expired         :  ${BIWhite}$exp_days${NC}"
echo -e "${BICyan} │  ${BICyan}Daily Bandwidth :  ${BIWhite}$daily_usage ${NC}"
echo -e "${BICyan} │  ${BICyan}Total Bandwidth :  ${BIWhite}$monthly_usage ${NC}"
echo -e "${BICyan} └────────────────────────────────────────────────────────────┘${NC}"
echo -e "      ${BICyan}SSH : $ressh ${BICyan} NGINX : $resngx ${BICyan}  XRAY : $resv2r ${BICyan} HAPROXY : $reshpx${NC}"
echo -e "      ${BICyan}DROPBEAR : $resdbr ${BICyan} SSH-WS : $ressshws ${BICyan} Stunnel : $resst${NC}"
echo -e "${BICyan} ┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "              ${BICyan}[${BIWhite}01${BICyan}]${BIWhite} SSHWS                      ${BICyan}|      [${BIWhite}06${BICyan}]${BIWhite} RESTORE EXPIRED USER${NC}"
echo -e "              ${BICyan}[${BIWhite}02${BICyan}]${BIWhite} VMESS                      ${BICyan}|      [${BIWhite}07${BICyan}]${BIWhite} USER BANDWIDTH${NC}"
echo -e "              ${BICyan}[${BIWhite}03${BICyan}]${BIWhite} VLESS                      ${BICyan}|      [${BIWhite}08${BICyan}]${BIWhite} RUNNING STATUS${NC}"
echo -e "              ${BICyan}[${BIWhite}04${BICyan}]${BIWhite} TROJAN                     ${BICyan}|      [${BIWhite}09${BICyan}]${BIWhite} BACKUP/RESTORE${NC}"
echo -e "              ${BICyan}[${BIWhite}05${BICyan}]${BIWhite} SHADOWSOCKS                ${BICyan}|      [${BIWhite}10${BICyan}]${BIWhite} FEATURES${NC}"
echo -e "${BICyan} └────────────────────────────────────────────────────────────┘${NC}"
echo -e "       ${BIWhite}SSH:${BICyan}[${BIWhite}${ssh}${BICyan}]   ${BIWhite}VMESS:${BICyan}[${BIWhite}${vmess}${BICyan}]   ${BIWhite}VLESS:${BICyan}[${BIWhite}${vless}${BICyan}]   ${BIWhite}TROJAN:${BICyan}[${BIWhite}${tr}${BICyan}]   ${BIWhite}SS:${BICyan}[${BIWhite}${ss}${BICyan}]${NC}"
echo -e "${BICyan} ┌────────────────────────────────────────────────────────────┐${NC}"
echo -e "     ${BIWhite}Version  :  ${BIGreen}$sem ${BIWhite}Last Update        type ${BIRed}x ${BIWhite}to exit${NC}"
echo -e "${BICyan} └────────────────────────────────────────────────────────────┘${NC}"
echo
read -p " Select menu : " opt
echo -e ""
case $opt in
1) clear && printf '\033[3J' ; menu-ssh ;;
2) clear && printf '\033[3J' ; menu-vmess ;;
3) clear && printf '\033[3J' ; menu-vless ;;
4) clear && printf '\033[3J' ; menu-trojan ;;
5) clear && printf '\033[3J' ; menu-ss ;;
6) clear && printf '\033[3J' ; cek-expired ;;
7) clear && printf '\033[3J' ; cek-trafik ;;
8) clear && printf '\033[3J' ; running ;;
9) menu_backup_restore ;;
10) menu_features ;;
0) clear && printf '\033[3J' ; menu ;;
x) exit ;;
*) echo -e "" ; echo "Press any key to back exit" ; sleep 1 ; exit ;;
esac
