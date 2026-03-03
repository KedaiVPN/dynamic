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
function del(){
clear && printf '\033[3J'
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m               DELETE USER                \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "USERNAME          EXP DATE          STATUS"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
while read expired
do
AKUN="$(echo $expired | cut -d: -f1)"
ID="$(echo $expired | grep -v nobody | cut -d: -f3)"
exp="$(chage -l $AKUN | grep "Account expires" | awk -F": " '{print $2}')"
status="$(passwd -S $AKUN | awk '{print $2}' )"
if [[ $ID -ge 1000 ]]; then
if [[ "$status" = "L" ]]; then
printf "%-17s %2s %-17s %2s \n" "$AKUN" "$exp     " "LOCKED${NORMAL}"
else
printf "%-17s %2s %-17s %2s \n" "$AKUN" "$exp     " "UNLOCKED${NORMAL}"
fi
fi
done < /etc/passwd
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
read -p "Username SSH to Delete : " Pengguna

if getent passwd $Pengguna > /dev/null 2>&1; then
        userdel $Pengguna > /dev/null 2>&1
        echo -e "User $Pengguna was removed."
else
        echo -e "Failure: User $Pengguna Not Exist."
fi

read -n 1 -s -r -p "Press any key to back on menu"

menu
}
function autodel(){
clear && printf '\033[3J'
               hariini=`date +%d-%m-%Y`
               echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
               echo -e "\E[0;41;36m               AUTO DELETE                \E[0m"
               echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"  
               echo "Thank you for removing the EXPIRED USERS"
               echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"  
               cat /etc/shadow | cut -d: -f1,8 | sed /:$/d > /tmp/expirelist.txt
               totalaccounts=`cat /tmp/expirelist.txt | wc -l`
               for((i=1; i<=$totalaccounts; i++ ))
               do
               tuserval=`head -n $i /tmp/expirelist.txt | tail -n 1`
               username=`echo $tuserval | cut -f1 -d:`
               userexp=`echo $tuserval | cut -f2 -d:`
               userexpireinseconds=$(( $userexp * 86400 ))
               tglexp=`date -d @$userexpireinseconds`             
               tgl=`echo $tglexp |awk -F" " '{print $3}'`
               while [ ${#tgl} -lt 2 ]
               do
               tgl="0"$tgl
               done
               while [ ${#username} -lt 15 ]
               do
               username=$username" " 
               done
               bulantahun=`echo $tglexp |awk -F" " '{print $2,$6}'`
               echo "echo "Expired- User : $username Expire at : $tgl $bulantahun"" >> /usr/local/bin/alluser
               todaystime=`date +%s`
               if [ $userexpireinseconds -ge $todaystime ] ;
               then
		    	:
               else
               echo "echo "Expired- Username : $username are expired at: $tgl $bulantahun and removed : $hariini "" >> /usr/local/bin/deleteduser
	           echo "Username $username that are expired at $tgl $bulantahun removed from the VPS $hariini"
               userdel $username
               fi
               done
               echo " "
               echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"  
               
               read -n 1 -s -r -p "Press any key to back on menu"
               menu
        
}
function ceklim(){
clear && printf '\033[3J'
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m         CHECK USER MULTI SSH        \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
if [ -e "/root/log-limit.txt" ]; then
echo "User Who Violate The Maximum Limit";
echo "Time - Username - Number of Multilogin"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
cat /root/log-limit.txt
else
echo " No user has committed a violation"
echo " "
echo " or"
echo " "
echo " The user-limit script not been executed."
fi
echo " ";
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo " ";
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function cek(){
clear && printf '\033[3J'
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m          User SSH Login           \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "Username   |  IP Address";
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

# --- Logic: AuthLog Port Map + WS Log Port Map + Netstat ---
WS_LOG_FILE="/var/log/ws-stunnel.log"

# 1. Build WS Map (Local Port -> Real IP)
declare -A PORT_TO_REAL_IP
if [ -f "$WS_LOG_FILE" ]; then
    while IFS="|" read -r ts action port ip; do
        if [ "$action" == "CONNECT" ]; then
            PORT_TO_REAL_IP[$port]="$ip"
        # elif [ "$action" == "DISCONNECT" ]; then
        #    unset PORT_TO_REAL_IP[$port]
        fi
    done < "$WS_LOG_FILE"
fi

# 2. Build Auth Map (Local Port -> Username) from Journalctl
declare -A PORT_TO_USER
RAW_LOGS=$(journalctl -u dropbear -u ssh -n 2000 --no-pager)

# Parse Dropbear
while read -r line; do
    if [[ "$line" =~ for\ \'([a-zA-Z0-9._-]+)\'\ from\ [0-9.]+:([0-9]+) ]]; then
        PORT_TO_USER[${BASH_REMATCH[2]}]="${BASH_REMATCH[1]}"
    fi
done <<< "$RAW_LOGS"

# Parse OpenSSH
while read -r line; do
    if [[ "$line" =~ for\ ([a-zA-Z0-9._-]+)\ from\ [0-9.]+\ port\ ([0-9]+) ]]; then
        PORT_TO_USER[${BASH_REMATCH[2]}]="${BASH_REMATCH[1]}"
    fi
done <<< "$RAW_LOGS"

# 3. Scan Netstat ESTABLISHED
if ! command -v netstat &> /dev/null; then
    apt-get install net-tools -y > /dev/null 2>&1
fi

netstat -tnp 2>/dev/null | grep 'ESTABLISHED' | grep -E 'sshd|dropbear' | while read -r line; do
    foreign_addr=$(echo "$line" | awk '{print $5}')
    ip=$(echo "$foreign_addr" | cut -d: -f1)
    port=$(echo "$foreign_addr" | cut -d: -f2)

    user=""
    real_ip="$ip"

    if [[ "$ip" == "127.0.0.1" || "$ip" == "localhost" ]]; then
        # Local Connection (Tunnel)
        user="${PORT_TO_USER[$port]}"

        mapped_ip="${PORT_TO_REAL_IP[$port]}"
        if [ -n "$mapped_ip" ]; then
            real_ip="$mapped_ip"
        fi
    else
        # Direct Connection
        user="${PORT_TO_USER[$port]}"
    fi

    if [[ -n "$user" && "$user" != "root" ]]; then
        echo "$user|$real_ip"
    fi

done | sort -u | while IFS="|" read -r user ip; do
    printf "%-10s | %s\n" "$user" "$ip"
done

echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

if [ -f "/etc/openvpn/server/openvpn-tcp.log" ]; then
        echo " "
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "\E[0;41;36m          OpenVPN TCP User Login         \E[0m"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo "Username  |  IP Address  |  Connected Since";
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        cat /etc/openvpn/server/openvpn-tcp.log | grep -w "^CLIENT_LIST" | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' > /tmp/vpn-login-tcp.txt
        cat /tmp/vpn-login-tcp.txt
fi
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

if [ -f "/etc/openvpn/server/openvpn-udp.log" ]; then
        echo " "
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "\E[0;41;36m          OpenVPN UDP User Login         \E[0m"
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo "Username  |  IP Address  |  Connected Since";
        echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        cat /etc/openvpn/server/openvpn-udp.log | grep -w "^CLIENT_LIST" | cut -d ',' -f 2,3,8 | sed -e 's/,/      /g' > /tmp/vpn-login-udp.txt
        cat /tmp/vpn-login-udp.txt
fi
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "";

rm -f /tmp/login-db-pid.txt
rm -f /tmp/login-db.txt
rm -f /tmp/vpn-login-tcp.txt
rm -f /tmp/vpn-login-udp.txt
read -n 1 -s -r -p "Press any key to back on menu"

menu
}
function member(){
clear && printf '\033[3J'
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m                 MEMBER SSH               \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"      
echo "USERNAME          EXP DATE          STATUS"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
while read expired
do
AKUN="$(echo $expired | cut -d: -f1)"
ID="$(echo $expired | grep -v nobody | cut -d: -f3)"
exp="$(chage -l $AKUN | grep "Account expires" | awk -F": " '{print $2}')"
status="$(passwd -S $AKUN | awk '{print $2}' )"
if [[ $ID -ge 1000 ]]; then
if [[ "$status" = "L" ]]; then
printf "%-17s %2s %-17s %2s \n" "$AKUN" "$exp     " "LOCKED${NORMAL}"
else
printf "%-17s %2s %-17s %2s \n" "$AKUN" "$exp     " "UNLOCKED${NORMAL}"
fi
fi
done < /etc/passwd
JUMLAH="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | wc -l)"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "Account number: $JUMLAH user"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function renew(){
clear && printf '\033[3J'
clear && printf '\033[3J'
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m               RENEW  USER                \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo "USERNAME          EXP DATE          STATUS"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
while read expired
do
AKUN="$(echo $expired | cut -d: -f1)"
ID="$(echo $expired | grep -v nobody | cut -d: -f3)"
exp="$(chage -l $AKUN | grep "Account expires" | awk -F": " '{print $2}')"
status="$(passwd -S $AKUN | awk '{print $2}' )"
if [[ $ID -ge 1000 ]]; then
if [[ "$status" = "L" ]]; then
printf "%-17s %2s %-17s %2s \n" "$AKUN" "$exp     " "LOCKED${NORMAL}"
else
printf "%-17s %2s %-17s %2s \n" "$AKUN" "$exp     " "UNLOCKED${NORMAL}"
fi
fi
done < /etc/passwd
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo
read -p "Username : " User
egrep "^$User" /etc/passwd >/dev/null
if [ $? -eq 0 ]; then
read -p "Day Extend : " Days
Today=`date +%s`
Days_Detailed=$(( $Days * 86400 ))
Expire_On=$(($Today + $Days_Detailed))
Expiration=$(date -u --date="1970-01-01 $Expire_On sec GMT" +%Y/%m/%d)
Expiration_Display=$(date -u --date="1970-01-01 $Expire_On sec GMT" '+%d %b %Y')
passwd -u $User
usermod -e  $Expiration $User
egrep "^$User" /etc/passwd >/dev/null
echo -e "$Pass\n$Pass\n"|passwd $User &> /dev/null
clear && printf '\033[3J'
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m               RENEW  USER                \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"  
echo -e ""
echo -e " Username : $User"
echo -e " Days Added : $Days Days"
echo -e " Expires on :  $Expiration_Display"
echo -e ""
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
else
clear && printf '\033[3J'
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m               RENEW  USER                \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"  
echo -e ""
echo -e "   Username Doesnt Exist      "
echo -e ""
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
fi
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function autokill(){
clear && printf '\033[3J'
Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[ON]${Font_color_suffix}"
Error="${Red_font_prefix}[OFF]${Font_color_suffix}"
cek=$(grep -c -E "^# Autokill" /etc/cron.d/tendang)
if [[ "$cek" = "1" ]]; then
sts="${Info}"
else
sts="${Error}"
fi
clear && printf '\033[3J'
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[44;1;39m             AUTOKILL SSH          \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "Status Autokill : $sts        "
echo -e ""
echo -e "[1]  AutoKill After 5 Minutes"
echo -e "[2]  AutoKill After 10 Minutes"
echo -e "[3]  AutoKill After 15 Minutes"
echo -e "[4]  Turn Off AutoKill/MultiLogin"
echo -e "[x]  Menu"
echo ""
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e ""
read -p "Select From Options [1-4 or x] :  " AutoKill
echo -e ""
case $AutoKill in
                1)
                echo -e ""
                sleep 1
                clear && printf '\033[3J'
                echo > /etc/cron.d/tendang
                echo "# Autokill" >/etc/cron.d/tendan
                mkdir -p /etc/ssh
                echo "5" > /etc/ssh/autokill-duration.conf
                echo "*/5 * * * *  root /usr/bin/tendang" >>/etc/cron.d/tendang && chmod +x /etc/cron.d/tendang
                echo "" > /root/log-limit.txt
                echo -e ""
                echo -e "======================================"
                echo -e ""
                echo -e "      AutoKill Every     : 5 Minutes"      
                echo -e ""
                echo -e "======================================"
                service cron reload >/dev/null 2>&1
                service cron restart >/dev/null 2>&1                                                                 
                ;;
                2)
                echo -e ""
                sleep 1
                clear && printf '\033[3J'
                echo > /etc/cron.d/tendang
                echo "# Autokill" >/etc/cron.d/tendang
                mkdir -p /etc/ssh
                echo "10" > /etc/ssh/autokill-duration.conf
                echo "*/10 * * * *  root /usr/bin/tendang" >>/etc/cron.d/tendang && chmod +x /etc/cron.d/tendang
                echo "" > /root/log-limit.txt
                echo -e ""
                echo -e "======================================"
                echo -e ""
                echo -e "      AutoKill Every     : 10 Minutes"
                echo -e ""
                echo -e "======================================"
                service cron reload >/dev/null 2>&1
                service cron restart >/dev/null 2>&1
                ;;
                3)
                echo -e ""
                sleep 1
                clear && printf '\033[3J'
                echo > /etc/cron.d/tendang
                echo "# Autokill" >/etc/cron.d/tendang
                mkdir -p /etc/ssh
                echo "15" > /etc/ssh/autokill-duration.conf
                echo "*/15 * * * *  root /usr/bin/tendang" >>/etc/cron.d/tendang && chmod +x /etc/cron.d/tendang
                echo "" > /root/log-limit.txt
                echo -e ""
                echo -e "======================================"
                echo -e ""
                echo -e "      AutoKill Every     : 15 Minutes"
                echo -e ""
                echo -e "======================================"
                service cron reload >/dev/null 2>&1
                service cron restart >/dev/null 2>&1          
                ;;
                4)
                rm -fr /etc/cron.d/tendang
                rm -f /etc/ssh/autokill-duration.conf
                echo "" > /root/log-limit.txt
                echo -e ""
                echo -e "======================================"
                echo -e ""
                echo -e "      AutoKill MultiLogin Turned Off"
                echo -e ""
                echo -e "======================================"
                service cron reload >/dev/null 2>&1
                service cron restart >/dev/null 2>&1
                ;;
                x)
                menu
                ;;
                *)
                echo "Please enter an correct number"
                ;;
        esac
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function editlimit(){
clear && printf '\033[3J'
read -p "Username : " Login
if id -u "$Login" >/dev/null 2>&1; then
        read -p "Limit login (1/2/3): " limitlogin
        if [ -z "$limitlogin" ]; then
                limitlogin=1
        fi
        limit_file="/etc/ssh/limit-user.conf"
        mkdir -p /etc/ssh
        if [ -f "$limit_file" ]; then
                awk -v user="$Login" '$1!=user' "$limit_file" > "${limit_file}.tmp" && mv "${limit_file}.tmp" "$limit_file"
        fi
        echo "$Login $limitlogin" >> "$limit_file"
        echo -e ""
        echo -e "Limit login $Login diatur ke $limitlogin"
        echo -e ""
else
        echo -e ""
        echo -e "   Username Doesnt Exist      "
        echo -e ""
fi
read -n 1 -s -r -p "Press any key to back on menu"
menu
}
function manual_lock_unlock(){
clear && printf '\033[3J'
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "\E[0;41;36m         MANUAL LOCK/UNLOCK SSH           \E[0m"
echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
read -p "Username : " Login
if id -u "$Login" >/dev/null 2>&1; then
    status=$(passwd -S "$Login" | awk '{print $2}')
    if [[ "$status" == "L" ]]; then
        echo -e "Status saat ini: [LOCKED]"
        read -p "Apakah anda ingin meng-UNLOCK user ini? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            usermod -U "$Login"
            rm -f "/tmp/lock-$Login"
            echo -e "${GREEN}User $Login telah di-UNLOCK.${NC}"
        else
            echo -e "${YELLOW}Dibatalkan.${NC}"
        fi
    else
        echo -e "Status saat ini: [UNLOCKED]"
        read -p "Apakah anda ingin meng-LOCK user ini? (y/n): " confirm
        if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
            usermod -L "$Login"
            touch "/tmp/lock-$Login"
            pkill -u "$Login"
            echo -e "${RED}User $Login telah di-LOCK dan sesi diputus.${NC}"
        else
            echo -e "${YELLOW}Dibatalkan.${NC}"
        fi
    fi
else
    echo -e "${RED}Username tidak ditemukan.${NC}"
fi
echo ""
read -n 1 -s -r -p "Press any key to back on menu"
menu
}

function trialssh(){
    clear && printf '\033[3J'
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\E[0;41;36m               TRIAL SSH                  \E[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

    rand_suffix=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)
    user="trialSSH${rand_suffix}"
    pass=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 3)

    read -p "Masa Aktif (Menit): " masa_aktif_menit

    if [[ -z "$masa_aktif_menit" || ! "$masa_aktif_menit" =~ ^[0-9]+$ ]]; then
        echo -e "${EROR} Input tidak valid!"
        sleep 2
        menu
    fi

    now=$(date +%s)
    exp_seconds=$((masa_aktif_menit * 60))
    exp_timestamp=$((now + exp_seconds))

    # Create user with 1 day expiry as fail-safe
    useradd -e $(date -d "+1 day" +"%Y-%m-%d") -s /bin/false -M $user
    echo -e "$pass\n$pass\n"|passwd $user &> /dev/null

    # Add to database
    echo "$user ssh $exp_timestamp" >> /etc/expired-users.db

    # Set Limit
    limit_file="/etc/ssh/limit-user.conf"
    mkdir -p /etc/ssh
    if [ -f "$limit_file" ]; then
        awk -v user="$user" '$1!=user' "$limit_file" > "${limit_file}.tmp" && mv "${limit_file}.tmp" "$limit_file"
    fi
    echo "$user 1" >> "$limit_file"

    # Display
    domain=$(cat /etc/xray/domain 2>/dev/null)
    if [[ -z "$domain" ]]; then
        domain=$(curl -s https://ipinfo.io/ip/)
    fi

    portsshws=$(cat /root/log-install.txt | grep -w "SSH Websocket" | cut -d: -f2 | awk '{print $1}')
    wsssl=$(cat /root/log-install.txt | grep -w "SSH SSL Websocket" | cut -d: -f2 | awk '{print $1}')
    opensh=$(cat /root/log-install.txt | grep -w "OpenSSH" | cut -f2 -d: | awk '{print $1}')
    db=$(cat /root/log-install.txt | grep -w "Dropbear" | cut -f2 -d: | awk '{print $1,$2}')
    ssl=$(cat /root/log-install.txt | grep -w "Stunnel5" | cut -d: -f2)

    clear && printf '\033[3J'
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "\E[0;41;36m          TRIAL SSH ACCOUNT        \E[0m"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "Username   : $user"
    echo -e "Password   : $pass"
    echo -e "Expired    : $masa_aktif_menit Menit"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "Host       : $domain"
    echo -e "OpenSSH    : $opensh"
    echo -e "Dropbear   : $db"
    echo -e "SSH-WS     : $portsshws"
    echo -e "SSH-SSL-WS : $wsssl"
    echo -e "SSL/TLS    : $ssl"
    echo -e "UDPGW      : 7100-7300"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "Payload WS"
    echo -e "GET / [protocol][crlf]Host: $domain[crlf]Connection: Keep-Alive[crlf]Connection: Upgrade[crlf]Upgrade: websocket[crlf][crlf]"
    echo -e "\033[0;34m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

    read -n 1 -s -r -p "Press any key to back on menu"
    menu
}

clear && printf '\033[3J'
echo -e "${BIRed} ╔═════════════════════════════════════════════════════╗${NC}"
echo -e "${BIRed} ║                   ${BIWhite}${UWhite}> SSH MENU <${NC}                      ${BIRed}║${NC}"
echo -e "${BIRed} ╠═════════════════════════════════════════════════════╣${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 1${BIRed}]${BIWhite} Add Account SSH                               ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 2${BIRed}]${BIWhite} Delete Account SSH                            ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 3${BIRed}]${BIWhite} Renew Account SSH                             ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 4${BIRed}]${BIWhite} Check User SSH                                ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 5${BIRed}]${BIWhite} Multilogin SSH                                ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 6${BIRed}]${BIWhite} Auto Delete user Expired                      ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 7${BIRed}]${BIWhite} Auto Kill user SSH                            ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 8${BIRed}]${BIWhite} Check Member SSH                              ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite} 9${BIRed}]${BIWhite} Edit Limit Login SSH                          ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite}10${BIRed}]${BIWhite} Lock/Unlock User SSH                          ${BIRed}║${NC}"
echo -e "${BIRed} ║   ${BIRed}[${BIWhite}11${BIRed}]${BIWhite} Trial Account SSH                             ${BIRed}║${NC}"
echo -e "${BIRed} ╚═════════════════════════════════════════════════════╝${NC}"
echo -e "     ${BIYellow}Press x or [ Ctrl+C ] • To-${BIWhite}Exit${NC}"
echo ""
read -p " Select menu : " opt
echo -e ""
case $opt in
1) clear && printf '\033[3J' ; usernew ;;
2) clear && printf '\033[3J' ; del ;;
3) clear && printf '\033[3J' ; renew;;
4) clear && printf '\033[3J' ; cek ;;
5) clear && printf '\033[3J' ; ceklim ;;
6) clear && printf '\033[3J' ; autodel ;;
7) clear && printf '\033[3J' ; autokill ;;
8) clear && printf '\033[3J' ; member ;;
9) clear && printf '\033[3J' ; editlimit ;;
10) clear && printf '\033[3J' ; manual_lock_unlock ;;
11) clear && printf '\033[3J' ; trialssh ;;
0) clear && printf '\033[3J' ; menu ;;
x) exit ;;
*) echo -e "" ; echo "Press any key to back on menu" ; sleep 1 ; menu ;;
esac
