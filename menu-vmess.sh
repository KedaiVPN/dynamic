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
green() { echo -e "\\033[32;1m${*}\\033[0m"; }
red() { echo -e "\\033[31;1m${*}\\033[0m"; }

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


clear && printf '\033[3J'

function cekws() {
clear && printf '\033[3J'
echo -n > /tmp/other.txt
data=( `cat /etc/xray/config.json | grep '#vms' | cut -d ' ' -f 2 | sort | uniq`);
echo "-------------------------------";
echo "-----=[ XRAY User Login ]=-----";
echo "-------------------------------";
for akun in "${data[@]}"
do
if [[ -z "$akun" ]]; then
akun="tidakada"
fi
echo -n > /tmp/ipxray.txt
data2=( `cat /var/log/xray/access.log | tail -n 500 | cut -d " " -f 3 | sed 's/tcp://g' | cut -d ":" -f 1 | sort | uniq`);
for ip in "${data2[@]}"
do
jum=$(cat /var/log/xray/access.log | grep -w "$akun" | tail -n 500 | cut -d " " -f 3 | sed 's/tcp://g' | cut -d ":" -f 1 | grep -w "$ip" | sort | uniq)
if [[ "$jum" = "$ip" ]]; then
echo "$jum" >> /tmp/ipxray.txt
else
echo "$ip" >> /tmp/other.txt
fi
jum2=$(cat /tmp/ipxray.txt)
sed -i "/$jum2/d" /tmp/other.txt > /dev/null 2>&1
done
jum=$(cat /tmp/ipxray.txt)
if [[ -z "$jum" ]]; then
echo > /dev/null
else
jum2=$(cat /tmp/ipxray.txt | nl)
lastlogin=$(cat /var/log/xray/access.log | grep -w "$akun" | tail -n 500 | cut -d " " -f 2 | tail -1)
echo -e "user :${GREEN} ${akun} ${NC}
${RED}Online Jam ${NC}: ${lastlogin} wib";
echo -e "$jum2";
echo "-------------------------------"
fi
rm -rf /tmp/ipxray.txt
done
rm -rf /tmp/other.txt

echo ""
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function detailws() {
clear && printf '\033[3J'
NUMBER_OF_CLIENTS=$(grep -c -E "^#vmsg " "/etc/xray/config.json")
	if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
		echo ""
		echo "You have no existing clients!"
		echo ""
		read -n 1 -s -r -p "Press any key to back on menu"
		menu
	fi

clear && printf '\033[3J'
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\\E[0;41;36m        Detail Vmess Account      \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
grep -E "^#vmsg " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | nl -w2 -s '. ' | sort | uniq
echo ""
read -rp "Input Username : " user
if [ -z "$user" ]; then
menu
fi
if [ -f "/home/vps/public_html/vmess-$user.txt" ]; then
clear && printf '\033[3J'
cat "/home/vps/public_html/vmess-$user.txt"
else
echo ""
echo "Account not found or detail file missing."
fi
echo ""
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function renewws(){
clear && printf '\033[3J'
NUMBER_OF_CLIENTS=$(grep -c -E "^#vmsg " "/etc/xray/config.json")
	if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
		clear && printf '\033[3J'
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "\\E[0;41;36m            Renew Vmess            \E[0m"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
		echo ""
		echo "You have no existing clients!"
		echo ""
		echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo ""
        read -n 1 -s -r -p "Press any key to back on menu"
        menu
	fi

	clear && printf '\033[3J'
	echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\\E[0;41;36m            Renew Vmess            \E[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
  	grep -E "^#vmsg " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | nl -w2 -s '. ' | sort | uniq
    echo ""
    red "tap enter to go back"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
	read -rp "Input Username : " user
    if [ -z $user ]; then
    menu
    else
    read -p "Expired (days): " masaaktif
    exp=$(grep -wE "^#vmsg $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
    now=$(date +%Y-%m-%d)
    d1=$(date -d "$exp" +%s)
    d2=$(date -d "$now" +%s)
    exp2=$(( (d1 - d2) / 86400 ))
    exp3=$(($exp2 + $masaaktif))
    exp4=`date -d "$exp3 days" +"%Y-%m-%d"`
    sed -i "/#vmsg $user/c\#vmsg $user $exp4" /etc/xray/config.json
    sed -i "/#vms $user/c\#vms $user $exp4" /etc/xray/config.json
    sed -i "/^### $user /c\### $user $exp4" /etc/xray/config.json
    limit_dir="/etc/xray/limit"
    limit_file="${limit_dir}/vmess"
    lock_file="${limit_dir}/lock-vmess"
    mkdir -p "$limit_dir"
    touch "$limit_file" "$lock_file"
    awk -v user="$user" -v exp="$exp4" 'BEGIN{OFS=" "} $1==user{$3=exp} {print}' "$limit_file" > "${limit_file}.tmp" && mv "${limit_file}.tmp" "$limit_file"
    awk -v user="$user" -v exp="$exp4" 'BEGIN{OFS=" "} $1==user{$3=exp} {print}' "$lock_file" > "${lock_file}.tmp" && mv "${lock_file}.tmp" "$lock_file"
    systemctl restart xray > /dev/null 2>&1
    clear && printf '\033[3J'
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo " VMESS Account Was Successfully Renewed"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    echo " Client Name : $user"
    echo " Expired On  : $exp4"
    echo ""
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo ""
    read -n 1 -s -r -p "Press any key to back on menu"
    menu
  fi
}
function delws() {
clear && printf '\033[3J'
NUMBER_OF_CLIENTS=$(grep -c -E "^#vmsg " "/etc/xray/config.json")
	if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
		echo ""
		echo "You have no existing clients!"
		exit 1
	fi

	clear && printf '\033[3J'
	echo ""
	echo " Select the existing client you want to remove"
	echo " Press CTRL+C to return"
	echo " ==============================="
	echo "     No  Expired   User"
	grep -E "^#vmsg " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | nl -s ') '
	until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
		if [[ ${CLIENT_NUMBER} == '1' ]]; then
			read -rp "Select one client [1]: " CLIENT_NUMBER
		else
			read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
		fi
	done
user=$(grep -E "^#vmsg " "/etc/xray/config.json" | cut -d ' ' -f 2 | sed -n "${CLIENT_NUMBER}"p)
exp=$(grep -E "^#vmsg " "/etc/xray/config.json" | cut -d ' ' -f 3 | sed -n "${CLIENT_NUMBER}"p)
sed -i "/^#vmsg $user $exp/,/^},{/d" /etc/xray/config.json
sed -i "/^#vms $user $exp/,/^},{/d" /etc/xray/config.json
sed -i "/^### $user $exp/,/^},{/d" /etc/xray/config.json
rm -f /etc/xray/vmess-$user-tls.json /etc/xray/vmess-$user-nontls.json
limit_dir="/etc/xray/limit"
limit_file="${limit_dir}/vmess"
lock_file="${limit_dir}/lock-vmess"
mkdir -p "$limit_dir"
touch "$limit_file" "$lock_file"
sed -i "/^$user /d" "$limit_file" "$lock_file"
systemctl restart xray.service
clear && printf '\033[3J'
echo ""
echo "==============================="
echo "  XRAYS/Vmess Account Deleted  "
echo "==============================="
echo "Username  : $user"
echo "Expired   : $exp"
echo "==============================="
echo "Script Mod By NevermoreSSH"
    echo ""
    read -n 1 -s -r -p "Press any key to back on menu"
    
    menu
}
function unlockws() {
clear && printf '\033[3J'
limit_dir="/etc/xray/limit"
lock_file="${limit_dir}/lock-vmess"
limit_file="${limit_dir}/vmess"
mkdir -p "$limit_dir"
touch "$lock_file" "$limit_file"
NUMBER_OF_CLIENTS=$(grep -c -E "^[^ ]" "$lock_file")
if [[ ${NUMBER_OF_CLIENTS} == '0' ]]; then
  echo ""
  echo "No locked VMESS accounts found!"
  echo ""
  read -n 1 -s -r -p "Press any key to back on menu"
  menu
fi

echo ""
echo " Select the locked client you want to unlock"
echo " Press CTRL+C to return"
echo " ==============================="
echo "     No  Expired   User"
nl -s ') ' "$lock_file" | awk '{print $1" "$4" "$2}'
until [[ ${CLIENT_NUMBER} -ge 1 && ${CLIENT_NUMBER} -le ${NUMBER_OF_CLIENTS} ]]; do
  if [[ ${CLIENT_NUMBER} == '1' ]]; then
    read -rp "Select one client [1]: " CLIENT_NUMBER
  else
    read -rp "Select one client [1-${NUMBER_OF_CLIENTS}]: " CLIENT_NUMBER
  fi
done
line=$(sed -n "${CLIENT_NUMBER}"p "$lock_file")
user=$(echo "$line" | awk '{print $1}')
uuid=$(echo "$line" | awk '{print $2}')
exp=$(echo "$line" | awk '{print $3}')
until [[ $quota =~ ^[0-9]+$ && $quota -gt 0 ]]; do
read -p "Limit Bandwidth (GB): " quota
done
reset_bytes=$(/usr/local/bin/xray api stats --server=127.0.0.1:10085 --name "user>>>${user}>>>traffic>>>uplink" 2>/dev/null | awk -F': ' 'NR==1{print $2}')
down_bytes=$(/usr/local/bin/xray api stats --server=127.0.0.1:10085 --name "user>>>${user}>>>traffic>>>downlink" 2>/dev/null | awk -F': ' 'NR==1{print $2}')
if [[ -z "$reset_bytes" ]]; then
  reset_bytes=0
fi
if [[ -z "$down_bytes" ]]; then
  down_bytes=0
fi
reset_bytes=$((reset_bytes + down_bytes))
sed -i "/^$user /d" "$lock_file"
sed -i "/^$user /d" "$limit_file"
echo "$user $uuid $exp $quota $reset_bytes" >> "$limit_file"
sed -i '/#vmess$/a\#vms '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
sed -i '/#vmessworry$/a\### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
sed -i '/#vmesskuota$/a\### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
sed -i '/#vmessgrpc$/a\#vmsg '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
systemctl restart xray >/dev/null 2>&1
clear && printf '\033[3J'
echo ""
echo "==============================="
echo "  XRAYS/Vmess Account Unlocked "
echo "==============================="
echo "Username  : $user"
echo "Expired   : $exp"
echo "Limit     : ${quota} GB"
echo "==============================="
echo ""
read -n 1 -s -r -p "Press any key to back on menu"
menu
}

function trialvmess(){
    clear && printf '\033[3J'
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\E[0;41;36m               TRIAL VMESS                \E[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

    rand_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)
    user="trialVM${rand_suffix}"

    read -p "Masa Aktif (Menit): " masa_aktif_menit
    if [[ -z "$masa_aktif_menit" || ! "$masa_aktif_menit" =~ ^[0-9]+$ ]]; then
        echo -e "${EROR} Input tidak valid!"
        sleep 2
        menu
    fi

    # Check if user exists
    CLIENT_EXISTS=$(grep -w $user /etc/xray/config.json | wc -l)
    if [[ ${CLIENT_EXISTS} == '1' ]]; then
        echo "User conflict, try again."
        sleep 2
        menu
    fi

    uuid=$(cat /proc/sys/kernel/random/uuid)
    quota=2

    # Timestamps
    now=$(date +%s)
    exp_seconds=$((masa_aktif_menit * 60))
    exp_timestamp=$((now + exp_seconds))
    exp_display=$(date -d "+${masa_aktif_menit} minutes" +"%Y-%m-%d")

    # Add to database
    echo "$user vmess $exp_timestamp" >> /etc/expired-users.db

    # Set Quota
    limit_dir="/etc/xray/limit"
    limit_file="${limit_dir}/vmess"
    lock_file="${limit_dir}/lock-vmess"
    mkdir -p "$limit_dir"
    touch "$limit_file" "$lock_file"
    sed -i "/^$user /d" "$limit_file" "$lock_file"
    echo "$user $uuid $exp_display $quota 0" >> "$limit_file"

    # Add to config.json
    sed -i '/#vmess$/a\#vms '"$user $exp_display"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#vmessworry$/a\### '"$user $exp_display"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#vmesskuota$/a\### '"$user $exp_display"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
    sed -i '/#vmessgrpc$/a\#vmsg '"$user $exp_display"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json

    # Generate links
    domain=$(cat /etc/xray/domain 2>/dev/null)
    if [[ -z "$domain" ]]; then
        domain=$(curl -s https://ipinfo.io/ip/)
    fi

    asu=`cat<<EOF
      {
      "v": "2",
      "ps": "VMESS_TLS_${user}",
      "add": "${domain}",
      "port": "443",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "tls"
}
EOF`
    ask=`cat<<EOF
      {
      "v": "2",
      "ps": "VMESS_NTLS_${user}",
      "add": "${domain}",
      "port": "80",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "none"
}
EOF`
    grpc=`cat<<EOF
      {
      "v": "2",
      "ps": "VMESS_GRPC_${user}",
      "add": "${domain}",
      "port": "443",
      "id": "${uuid}",
      "aid": "0",
      "net": "grpc",
      "path": "vmess-grpc",
      "type": "none",
      "host": "${domain}",
      "tls": "tls"
}
EOF`

    vmesslink1="vmess://$(echo $asu | base64 -w 0)"
    vmesslink2="vmess://$(echo $ask | base64 -w 0)"
    vmesslink5="vmess://$(echo $grpc | base64 -w 0)"

    # Restart Xray
    systemctl restart xray > /dev/null 2>&1

    # Display
    clear && printf '\033[3J'
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\E[0;41;36m       TRIAL VMESS ACCOUNT         \E[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "Remarks   : ${user}"
    echo -e "Domain    : ${domain}"
    echo -e "Port TLS  : 443"
    echo -e "Port none : 80"
    echo -e "ID        : ${uuid}"
    echo -e "Limit     : ${quota} GB"
    echo -e "Expired   : ${masa_aktif_menit} Menit"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "Link TLS  : ${vmesslink1}"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "Link None : ${vmesslink2}"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "Link GRPC : ${vmesslink5}"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

    read -n 1 -s -r -p "Press any key to back on menu"
    menu
}

clear && printf '\033[3J'
echo -e "${BIRed} ╔═════════════════════════════════════════════════════╗${NC}"
echo -e "${BIRed} ║                   ${BIWhite}${UWhite}> VMESS MENU <${NC}                    ${BIRed}║${NC}"
echo -e "${BIRed} ╠═════════════════════════════════════════════════════╣${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 1${BIRed}]${BIWhite} Add Account Vmess                            ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 2${BIRed}]${BIWhite} Delete Account Vmess                         ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 3${BIRed}]${BIWhite} Renew Account Vmess                          ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 4${BIRed}]${BIWhite} Check User XRAY                              ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 5${BIRed}]${BIWhite} Unlock Account Vmess                         ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 6${BIRed}]${BIWhite} Check Detail Account                         ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 7${BIRed}]${BIWhite} Trial Account Vmess                          ${BIRed}║${NC}"
echo -e "${BIRed} ╚═════════════════════════════════════════════════════╝${NC}"
echo -e "     ${BIYellow}Press x or [ Ctrl+C ] • To-${BIWhite}Exit${NC}"
echo ""
read -p " Select menu : " opt
echo -e ""
case $opt in
1) clear && printf '\033[3J' ; add-ws ;;
2) clear && printf '\033[3J' ; delws ;;
3) clear && printf '\033[3J' ; renewws;;
4) clear && printf '\033[3J' ; cekws ;;
5) clear && printf '\033[3J' ; unlockws ;;
6) clear && printf '\033[3J' ; detailws ;;
7) clear && printf '\033[3J' ; trialvmess ;;
0) clear && printf '\033[3J' ; menu ;;
x) exit ;;
*) echo -e "" ; echo "Press any key to back on menu" ; sleep 1 ; menu ;;
esac
