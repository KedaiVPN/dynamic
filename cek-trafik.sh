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
white="\033[1;97m"
line_color="\033[1;92m"

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

# // Validate Result ( 1 )
touch

clear && printf '\033[3J'
_APISERVER=127.0.0.1:10085
_Xray="$(command -v xray)"
if [[ -z "$_Xray" ]]; then
  _Xray=/usr/local/bin/xray
fi

limit_dir="/etc/xray/limit"
vmess_file="${limit_dir}/vmess"
vless_file="${limit_dir}/vless"
trojan_file="${limit_dir}/trojan"
lock_vmess="${limit_dir}/lock-vmess"
lock_vless="${limit_dir}/lock-vless"
lock_trojan="${limit_dir}/lock-trojan"
usage_vmess="${limit_dir}/usage-vmess"
usage_vless="${limit_dir}/usage-vless"
usage_trojan="${limit_dir}/usage-trojan"

mkdir -p "$limit_dir"
touch "$vmess_file" "$vless_file" "$trojan_file" "$lock_vmess" "$lock_vless" "$lock_trojan" "$usage_vmess" "$usage_vless" "$usage_trojan"

format_bytes() {
  local bytes="$1"
  awk -v b="$bytes" 'BEGIN {
    if (b < 1024) {
      printf "%.2fB", b
    } else if (b < 1024*1024) {
      printf "%.2fKB", b/1024
    } else if (b < 1024*1024*1024) {
      printf "%.2fMB", b/1024/1024
    } else {
      printf "%.2fGB", b/1024/1024/1024
    }
  }'
}

get_stat_value() {
  local name="$1"
  local value
  value="$("$_Xray" api stats --server=$_APISERVER --name "$name" 2>/dev/null | awk -F': ' '/"value"/{print $2; exit}')"
  if [[ -z "$value" ]]; then
    echo 0
    return
  fi
  echo "$value"
}

get_usage_bytes() {
  local user="$1"
  local up down
  up="$(get_stat_value "user>>>${user}>>>traffic>>>uplink")"
  down="$(get_stat_value "user>>>${user}>>>traffic>>>downlink")"
  echo $((up + down))
}

get_usage_record() {
  local usage_file="$1"
  local user="$2"
  local record
  record="$(awk -v u="$user" '$1==u{print $2, $3}' "$usage_file")"
  if [[ -z "$record" ]]; then
    echo "0 0"
    return
  fi
  echo "$record"
}

update_usage_record() {
  local usage_file="$1"
  local user="$2"
  local offset="$3"
  local last_seen="$4"
  sed -i "/^${user} /d" "$usage_file"
  echo "$user $offset $last_seen" >> "$usage_file"
}

print_header() {
  local title="$1"
  echo -e "${red} ╔═════════════════════════════════════════════════════╗${NC}"
  printf "${red} ║ %-51s ${red}║${NC}\n" "                ${white}> $title <                "
  echo -e "${red} ╠═════════════════════════════════════════════════════╣${NC}"
  printf "${red} ║ ${white}    %-12s %-14s %-14s %-5s ${red}║${NC}\n" "USER" "USED(GB)" "LIMIT(GB)" "STATUS"
  echo -e "${red} ╠═════════════════════════════════════════════════════╣${NC}"
}

print_protocol() {
  local proto="$1"
  local file="$2"
  local lock_file="$3"
  local usage_file="$4"
  local has_data=0

  while read -r user uuid exp limit_gb reset_bytes; do
    if [[ -z "$user" || -z "$limit_gb" ]]; then
      continue
    fi
    has_data=1
    if [[ -z "$reset_bytes" || ! "$reset_bytes" =~ ^[0-9]+$ ]]; then
      reset_bytes=0
    fi
    usage="$(get_usage_bytes "$user")"
    read -r offset last_seen <<< "$(get_usage_record "$usage_file" "$user")"
    if [[ "$usage" -lt "$last_seen" ]]; then
      offset=$((offset + last_seen))
    fi
    update_usage_record "$usage_file" "$user" "$offset" "$usage"
    total_bytes=$((offset + usage))
    used_bytes=$((total_bytes - reset_bytes))
    if [[ "$used_bytes" -lt 0 ]]; then
      used_bytes=0
    fi
    used_display="$(format_bytes "$used_bytes")"
    limit_display="${limit_gb}GB"
    status="UNLOCKED"
    if grep -q -E "^${user} " "$lock_file"; then
      status="LOCKED"
    fi
    printf "${red} ║ ${white}    %-12s %-14s %-14s %-5s ${red}║${NC}\n" "$user" "$used_display" "$limit_display" "$status"
  done < "$file"

  if [[ "$has_data" -eq 0 ]]; then
    printf "${red} ║ ${white}        %-43s ${red}║${NC}\n" "No users found."
  fi
  echo -e "${red} ╚═════════════════════════════════════════════════════╝${NC}"
}

if [[ ! -x "$_Xray" ]]; then
  echo "Xray binary not found."
  exit 0
fi

print_header "VMESS USERS"
print_protocol "vmess" "$vmess_file" "$lock_vmess" "$usage_vmess"
echo ""
print_header "VLESS USERS"
print_protocol "vless" "$vless_file" "$lock_vless" "$usage_vless"
echo ""
print_header "TROJAN USERS"
print_protocol "trojan" "$trojan_file" "$lock_trojan" "$usage_trojan"
