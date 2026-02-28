#!/bin/bash
# =========================================
# Quick Setup | Script Setup Manager
# Edition : Stable Edition V1.0
# Auther  : NevermoreSSH
# (C) Copyright 2022
# =========================================
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
IP=$(curl -s ipinfo.io/ip )
IP=$(curl -sS ipv4.icanhazip.com)
IP=$(curl -sS ifconfig.me )

# // Exporting Network Interface
export NETWORK_IFACE="$(ip route show to default | awk '{print $5}')"


clear && printf '\033[3J'
# source /var/lib/scrz-prem/ipvps.conf # This is usually missing on fresh installs

# Fix Domain Detection Logic
mkdir -p /etc/xray
domain=""

# Try reading from file first
if [[ -f /etc/xray/domain ]]; then
    domain=$(cat /etc/xray/domain)
fi

# Try reading from ipvps.conf if still empty
if [[ -z "$domain" ]] && [[ -f /var/lib/scrz-prem/ipvps.conf ]]; then
    source /var/lib/scrz-prem/ipvps.conf
    domain=$domain # Usually exported in conf
fi

# If still empty, ask user
if [[ -z "$domain" ]]; then
    echo -e "${EROR} Domain Not Found!"
    exit 1
fi

echo -e "[ ${GREEN}INFO${NC} ] Checking... "
sleep 1
echo -e "[ ${GREEN}INFO$NC ] Setting ntpdate"
sleep 1
# domain=$(cat /root/domain) # Use the verified $domain variable instead
export DEBIAN_FRONTEND=noninteractive
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
apt install iptables iptables-persistent -y
apt install curl socat xz-utils wget apt-transport-https gnupg gnupg2 gnupg1 dnsutils lsb-release -y
apt install socat cron bash-completion ntpdate -y
#ntpdate pool.ntp.org
ntpdate -u pool.ntp.org
apt -y install chrony
timedatectl set-ntp true
#systemctl enable chronyd && systemctl restart chronyd
systemctl enable chrony && systemctl restart chrony
timedatectl set-timezone Asia/Jakarta
#chronyc sourcestats -v
#chronyc tracking -v
apt install curl pwgen openssl netcat cron unzip haproxy python2 -y

# Make Folder & Log XRay & Log Trojan
rm -fr /var/log/xray
#rm -fr /var/log/trojan
rm -fr /home/vps/public_html
mkdir -p /var/log/xray
#mkdir -p /var/log/trojan
mkdir -p /home/vps/public_html
# chown www-data.www-data /var/log/xray # Moved to after touch
chown www-data.www-data /etc/xray
chmod +x /var/log/xray
#chmod +x /var/log/trojan
touch /var/log/xray/access.log
touch /var/log/xray/error.log
touch /var/log/xray/access2.log
touch /var/log/xray/error2.log
# Make Log Autokill & Log Autoreboot
rm -fr /root/log-limit.txt
rm -fr /root/log-reboot.txt
touch /root/log-limit.txt
touch /root/log-reboot.txt
touch /home/limit
echo "" > /root/log-limit.txt
echo "" > /root/log-reboot.txt
mkdir -p /etc/xray/limit
touch /etc/xray/limit/vmess /etc/xray/limit/vless /etc/xray/limit/trojan
touch /etc/xray/limit/lock-vmess /etc/xray/limit/lock-vless /etc/xray/limit/lock-trojan
touch /etc/xray/limit/usage-vmess /etc/xray/limit/usage-vless /etc/xray/limit/usage-trojan

# FIX PERMISSIONS: Ensure www-data owns all logs we just created
chown -R www-data:www-data /var/log/xray
chmod -R 755 /var/log/xray

# Install Wondershaper
cd /root/
apt install wondershaper -y
git clone https://github.com/magnific0/wondershaper.git >/dev/null 2>&1
cd wondershaper
make install
cd
rm -fr /root/wondershaper
echo > /home/limit

# nginx for debian & ubuntu
install_ssl(){
    if [ -f "/usr/bin/apt-get" ];then
            isDebian=`cat /etc/issue|grep Debian`
            if [ "$isDebian" != "" ];then
                    apt-get install -y nginx certbot
                    apt install -y nginx certbot
                    sleep 3s
            else
                    apt-get install -y nginx certbot
                    apt install -y nginx certbot
                    sleep 3s
            fi
    else
        yum install -y nginx certbot
        sleep 3s
    fi

    systemctl stop nginx.service

    if [ -f "/usr/bin/apt-get" ];then
            isDebian=`cat /etc/issue|grep Debian`
            if [ "$isDebian" != "" ];then
                    echo "A" | certbot certonly --renew-by-default --register-unsafely-without-email --standalone -d $domain
                    sleep 3s
            else
                    echo "A" | certbot certonly --renew-by-default --register-unsafely-without-email --standalone -d $domain
                    sleep 3s
            fi
    else
        echo "Y" | certbot certonly --renew-by-default --register-unsafely-without-email --standalone -d $domain
        sleep 3s
    fi
}

# Install HAProxy Config
rm -fr /etc/haproxy/haproxy.cfg
cat >/etc/haproxy/haproxy.cfg <<EOF
# CFG LOADBALANCER NEWBIE STORE [ \$domain ]
global
    stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
    stats timeout 1d

    log /dev/log local0
    log /dev/log local1 notice
    log /dev/log local0 info

    tune.h2.initial-window-size 2147483647
    tune.ssl.default-dh-param 2048

    pidfile /run/haproxy.pid
    chroot /var/lib/haproxy

    user haproxy
    group haproxy
    daemon

    ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
    ssl-default-bind-options no-sslv3 no-tlsv10 no-tlsv11

    ca-base /etc/ssl/certs
    crt-base /etc/ssl/private

defaults
    log global
    mode tcp
    option tcplog
    option httplog
    option dontlognull
    timeout connect 60s
    timeout client  300s
    timeout server  300s

frontend http_frontend
    mode tcp
    bind *:80 tfo
    bind *:8080 tfo
    bind *:8880 tfo
    bind *:2080 tfo
    bind *:2082 tfo

    tcp-request inspect-delay 500ms
    tcp-request content accept if HTTP
    acl is_websocket hdr(Upgrade) -i websocket

    use_backend ws_backend if is_websocket
    default_backend dropbear_backend

frontend https_frontend
    bind *:443 ssl crt /etc/xray/xray.pem tfo alpn h2,http/1.1
    mode tcp
    log global
    option tcplog
    tcp-request inspect-delay 500ms
    tcp-request content accept if { req.ssl_hello_type 1 }

    acl is_websocket_ssl hdr(Upgrade) -i websocket
    acl is_http2 ssl_fc_alpn -i h2

    use_backend ws_backend if is_websocket_ssl
    use_backend grpc_backend if is_http2
    default_backend dropbear_backend

backend dropbear_backend
    mode tcp
    server dropbear_server 127.0.0.1:58080 check

backend ws_backend
    mode tcp
    server ws_server 127.0.0.1:1010 check send-proxy

backend grpc_backend
    mode tcp
    server grpc_server 127.0.0.1:1013 check send-proxy
EOF

# install nginx
apt install -y nginx
cd
rm -fr /etc/nginx/sites-enabled/default
rm -fr /etc/nginx/sites-available/default
# wget -q -O /etc/nginx/nginx.conf "https://raw.githubusercontent.com/NevermoreSSH/Blueblue/main/nginx.conf" 
# Embed nginx.conf with Proxy Protocol support for Xray frontend
# Merging user optimizations
rm -fr /etc/nginx/nginx.conf
cat >/etc/nginx/nginx.conf <<EOF
user www-data;
worker_processes auto;
worker_rlimit_nofile 65536;
pid /var/run/nginx.pid;

events {
    multi_accept on;
    worker_connections 2048;
}

http {
    gzip on;
    gzip_vary on;
    gzip_comp_level 5;
    gzip_types text/plain application/x-javascript text/xml text/css;
    autoindex on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    client_max_body_size 32M;
    client_header_buffer_size 8m;
    large_client_header_buffers 8 8m;
    fastcgi_buffer_size 8m;
    fastcgi_buffers 8 8m;
    fastcgi_read_timeout 600;
    
    # CloudFlare IPv4
    set_real_ip_from 199.27.128.0/21;
    set_real_ip_from 173.245.48.0/20;
    set_real_ip_from 103.21.244.0/22;
    set_real_ip_from 103.22.200.0/22;
    set_real_ip_from 103.31.4.0/22;
    set_real_ip_from 141.101.64.0/18;
    set_real_ip_from 108.162.192.0/18;
    set_real_ip_from 190.93.240.0/20;
    set_real_ip_from 188.114.96.0/20;
    set_real_ip_from 197.234.240.0/22;
    set_real_ip_from 198.41.128.0/17;
    set_real_ip_from 162.158.0.0/15;
    set_real_ip_from 104.16.0.0/12;

    # Incapsula
    set_real_ip_from 199.83.128.0/21;
    set_real_ip_from 198.143.32.0/19;
    set_real_ip_from 149.126.72.0/21;
    set_real_ip_from 103.28.248.0/22;
    set_real_ip_from 45.64.64.0/22;
    set_real_ip_from 185.11.124.0/22;
    set_real_ip_from 192.230.64.0/18;
    
    real_ip_header CF-Connecting-IP;

    include /etc/nginx/conf.d/*.conf;
}
EOF

#mkdir -p /home/vps/public_html
#wget -q -O /etc/nginx/conf.d/vps.conf "https://raw.githubusercontent.com/NevermoreSSH/Blueblue/main/vps.conf"
rm -f /etc/nginx/conf.d/vps.conf

# Install Xray #
#==========#
# Use specific stable version known to work (v24.11.30) instead of latest (v26+)
# to avoid deprecation issues with VMess/WebSocket
latest_version="v24.11.30"

# Detect Architecture
arch=$(uname -m)
if [[ "$arch" == "x86_64" ]]; then
    xraycore_link="https://github.com/XTLS/Xray-core/releases/download/$latest_version/Xray-linux-64.zip"
elif [[ "$arch" == "aarch64" ]]; then
    xraycore_link="https://github.com/XTLS/Xray-core/releases/download/$latest_version/Xray-linux-arm64-v8a.zip"
else
    echo -e "[ ${RED}ERROR${NC} ] Unsupported Architecture: $arch"
    exit 1
fi

echo -e "[ ${GREEN}INFO${NC} ] Downloading Xray $latest_version for $arch..."
cd `mktemp -d`
curl -sL "$xraycore_link" -o xray.zip
unzip -q xray.zip
if [[ -f "xray" ]]; then
    rm -rf xray.zip
    mv xray /usr/local/bin/xray
    chmod +x /usr/local/bin/xray
    echo -e "[ ${GREEN}INFO${NC} ] Xray installed successfully."
else
    echo -e "[ ${RED}ERROR${NC} ] Failed to extract xray binary!"
    # Try to find it if it's in a subfolder
    found_bin=$(find . -type f -name "xray" | head -n 1)
    if [[ -n "$found_bin" ]]; then
        mv "$found_bin" /usr/local/bin/xray
        chmod +x /usr/local/bin/xray
        echo -e "[ ${GREEN}INFO${NC} ] Xray installed successfully (from subfolder)."
    else
        echo -e "[ ${RED}ERROR${NC} ] Xray binary not found. Aborting."
        exit 1
    fi
fi
cd

# / / Make Main Directory
mkdir -p /usr/bin/xray
mkdir -p /etc/xray
mkdir -p /usr/local/etc/xray

# // Making Certificate
clear && printf '\033[3J'
echo -e "[ ${GREEN}INFO${NC} ] Starting renew cert... " 
sleep 2
echo -e "${OKEY} Starting Generating Certificate"
##Generate acme certificate
# Stop services first to free port 80/443
systemctl stop nginx
systemctl stop xray
# Kill any rogue process on 80/443
kill $(lsof -t -i:80) >/dev/null 2>&1
kill $(lsof -t -i:443) >/dev/null 2>&1

if [[ -n "$domain" ]]; then
    chown -R nobody:nogroup /etc/xray
    chmod 644 /etc/xray/xray.crt
    chmod 644 /etc/xray/xray.key

    # HAProxy requires combined PEM
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/xray/xray.pem
    chmod 644 /etc/xray/xray.pem

    echo -e "${OKEY} Your Domain : $domain"
else
    echo -e "${EROR} Domain Not Found! Certificate generation skipped."
    # We exit here because Xray won't start without certs
    exit 1
fi

# Configure Dropbear to listen on port 58080 (for HAProxy)
if [ -f /etc/default/dropbear ]; then
    # Backup
    cp /etc/default/dropbear /etc/default/dropbear.bak

    # Check if 58080 is already present
    if ! grep -q "58080" /etc/default/dropbear; then
        # Append -p 58080 to DROPBEAR_EXTRA_ARGS
        sed -i 's/DROPBEAR_EXTRA_ARGS="/DROPBEAR_EXTRA_ARGS="-p 58080 /g' /etc/default/dropbear
    fi

    # Restart Dropbear
    /etc/init.d/dropbear restart
fi

# Ensure ws-stunnel is running on port 10015
if [ -f /usr/local/bin/ws-stunnel ]; then
    cat > /etc/systemd/system/ws-stunnel.service << END
[Unit]
Description=SSH Websocket Tunnel
Documentation=https://github.com/KedaiVPN
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/python2 -O /usr/local/bin/ws-stunnel 10015
Restart=on-failure

[Install]
WantedBy=multi-user.target
END

    systemctl daemon-reload
    systemctl enable ws-stunnel
    systemctl restart ws-stunnel
else
    # Try to download if missing (fallback)
    wget -q -O /usr/local/bin/ws-stunnel "https://raw.githubusercontent.com/NevermoreSSH/Blueblue/main/ws-stunnel"
    chmod +x /usr/local/bin/ws-stunnel

    cat > /etc/systemd/system/ws-stunnel.service << END
[Unit]
Description=SSH Websocket Tunnel
Documentation=https://github.com/KedaiVPN
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/bin/python2 -O /usr/local/bin/ws-stunnel 10015
Restart=on-failure

[Install]
WantedBy=multi-user.target
END
    systemctl daemon-reload
    systemctl enable ws-stunnel
    systemctl restart ws-stunnel
fi

# nginx renew ssl
echo -n '#!/bin/bash
/etc/init.d/nginx stop
/etc/init.d/xray stop
"/root/.acme.sh"/acme.sh --cron --home "/root/.acme.sh" &> /root/renew_ssl.log
/etc/init.d/nginx start
/etc/init.d/xray start
' > /usr/local/bin/ssl_renew.sh
chmod +x /usr/local/bin/ssl_renew.sh
if ! grep -q 'ssl_renew.sh' /var/spool/cron/crontabs/root;then (crontab -l;echo "15 03 */3 * * /usr/local/bin/ssl_renew.sh") | crontab;fi


# Fixed Ports for Stability
vless=10001
vmess=10002
trojanws=10003
ssws=10004
vlessgrpc=10005
vmessgrpc=10006
trojangrpc=10007
ssgrpc=10008

# UPDATE log-install.txt so add-ws.sh knows the TLS port (443)
# We need to make sure 'Vmess TLS' grep returns '443'
sed -i 's/Vmess TLS         : .*/Vmess TLS         : 443/g' /root/log-install.txt
sed -i 's/Vmess None TLS    : .*/Vmess None TLS    : 80/g' /root/log-install.txt
sed -i 's/Vless TLS         : .*/Vless TLS         : 443/g' /root/log-install.txt
sed -i 's/Vless None TLS    : .*/Vless None TLS    : 80/g' /root/log-install.txt
sed -i 's/Trojan .*         : .*/Trojan WS         : 443/g' /root/log-install.txt

# nginx xray.conf - Behind HAProxy
rm -fr /etc/nginx/conf.d/xray.conf
cat >/etc/nginx/conf.d/xray.conf <<EOF
server {
    listen 127.0.0.1:1010 proxy_protocol;
    server_name 127.0.0.1 localhost $domain;

    # User Optimization
    client_body_buffer_size 200K;
    client_header_buffer_size 2k;
    client_max_body_size 10M;
    large_client_header_buffers 3 1k;
    client_header_timeout 360s;
    keepalive_timeout 360s;

    root /home/vps/public_html;

    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10015;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ~ \.php$ {
        include /etc/nginx/fastcgi_params;
        fastcgi_pass  127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    # WebSocket Locations
    location ~ /vless {
        if (\$http_upgrade != "Websocket") {
            rewrite /(.*) /vless break;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ~ /vmess {
        if (\$http_upgrade != "Websocket") {
            rewrite /(.*) /vmess break;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ~ /trojan-ws {
        if (\$http_upgrade != "Websocket") {
            rewrite /(.*) /trojan-ws break;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ~ /ss-ws {
        if (\$http_upgrade != "Websocket") {
            rewrite /(.*) /ss-ws break;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10004;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}

server {
    listen 127.0.0.1:1013 proxy_protocol http2;
    server_name 127.0.0.1 localhost $domain;

    # gRPC Locations
    location ^~ /vless-grpc {
        proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10005;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ^~ /vmess-grpc {
        proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10006;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ^~ /trojan-grpc {
        proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10007;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location ^~ /ss-grpc {
        proxy_redirect off;
        grpc_set_header Host \$host;
        grpc_pass grpc://127.0.0.1:10008;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF
#pw sodosok
openssl rand -base64 16 > /etc/xray/passwd
bijikk=$(openssl rand -base64 16 )
pelerr=$(cat /etc/xray/passwd)

# set uuid xray
uuid=$(cat /proc/sys/kernel/random/uuid)

# xray config - Simplified Backend Only
cat <<EOF> /etc/xray/config.json
{
  "log" : {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
      {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
   {
     "listen": "127.0.0.1",
     "port": 10001,
     "protocol": "vless",
      "settings": {
          "decryption":"none",
            "clients": [
               {
                 "id": "${uuid}"                 
#vless
             }
          ]
       },
       "streamSettings":{
         "network": "ws",
            "wsSettings": {
                "path": "/vless"
          }
        }
     },
     {
     "listen": "127.0.0.1",
     "port": 10002,
     "protocol": "vmess",
      "settings": {
            "clients": [
               {
                 "id": "${uuid}",
                 "alterId": 0
#vmess
             }
          ]
       },
       "streamSettings":{
         "network": "ws",
            "wsSettings": {
                "path": "/vmess"
          }
        }
     },
     {
     "listen": "127.0.0.1",
     "port": 10003,
     "protocol": "trojan",
      "settings": {
          "decryption":"none",		
           "clients": [
              {
                 "password": "${uuid}"
#trojanws
              }
          ],
         "udp": true
       },
       "streamSettings":{
           "network": "ws",
           "wsSettings": {
               "path": "/trojan-ws"
            }
         }
     },
    {
         "listen": "127.0.0.1",
        "port": 10004,
        "protocol": "shadowsocks",
        "settings": {
           "clients": [
           {
           "method": "aes-128-gcm",
          "password": "${uuid}"
#ssws
           }
          ],
          "network": "tcp,udp"
       },
       "streamSettings":{
          "network": "ws",
             "wsSettings": {
               "path": "/ss-ws"
           }
        }
     },	
      {
        "listen": "127.0.0.1",
        "port": 10005,
        "protocol": "vless",
        "settings": {
         "decryption":"none",
           "clients": [
             {
               "id": "${uuid}"
#vlessgrpc
             }
          ]
       },
          "streamSettings":{
             "network": "grpc",
             "grpcSettings": {
                "serviceName": "vless-grpc"
           }
        }
     },
     {
      "listen": "127.0.0.1",
      "port": 10006,
     "protocol": "vmess",
      "settings": {
            "clients": [
               {
                 "id": "${uuid}",
                 "alterId": 0
#vmessgrpc
             }
          ]
       },
       "streamSettings":{
         "network": "grpc",
            "grpcSettings": {
                "serviceName": "vmess-grpc"
          }
        }
     },
     {
        "listen": "127.0.0.1",
        "port": 10007,
        "protocol": "trojan",
        "settings": {
          "decryption":"none",
             "clients": [
               {
                 "password": "${uuid}"
#trojangrpc
               }
           ]
        },
         "streamSettings":{
         "network": "grpc",
           "grpcSettings": {
               "serviceName": "trojan-grpc"
         }
      }
   },
   {
    "listen": "127.0.0.1",
    "port": 10008,
    "protocol": "shadowsocks",
    "settings": {
        "clients": [
          {
             "method": "aes-128-gcm",
             "password": "${uuid}"
#ssgrpc
           }
         ],
           "network": "tcp,udp"
      },
    "streamSettings":{
     "network": "grpc",
        "grpcSettings": {
           "serviceName": "ss-grpc"
          }
       }
    }	
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    },
	{
  "protocol": "freedom",
  "settings": {},
  "tag": "api"
    },

    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      },
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": [
          "bittorrent"
        ]
      }
    ]
  },
  "stats": {},
  "api": {
    "services": [
      "StatsService"
    ],
    "tag": "api"
  },
  "policy": {
    "levels": {
      "0": {
        "statsUserDownlink": true,
        "statsUserUplink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink" : true,
      "statsOutboundDownlink" : true
    }
  }
}
EOF
# Installing Xray Service
rm -fr /etc/systemd/system/xray.service.d
rm -fr /etc/systemd/system/xray.service
cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE                            
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF

echo -e "[ ${GREEN}ok${NC} ] Enable & Start & Restart & Xray"
systemctl daemon-reload >/dev/null 2>&1
systemctl enable xray >/dev/null 2>&1
systemctl start xray >/dev/null 2>&1
systemctl restart xray >/dev/null 2>&1
echo -e "[ ${GREEN}ok${NC} ] Enable & Start & Restart & Nginx"
systemctl daemon-reload >/dev/null 2>&1
systemctl enable nginx >/dev/null 2>&1
systemctl start nginx >/dev/null 2>&1
systemctl restart nginx >/dev/null 2>&1
echo -e "[ ${GREEN}ok${NC} ] Enable & Start & Restart & HAProxy"
systemctl daemon-reload >/dev/null 2>&1
systemctl enable haproxy >/dev/null 2>&1
systemctl start haproxy >/dev/null 2>&1
systemctl restart haproxy >/dev/null 2>&1

# Restart All Service
echo -e "$yell[SERVICE]$NC Restart All Service"
sleep 1
chown -R www-data:www-data /home/vps/public_html
# Enable & Restart & Xray & Trojan & Nginx & HAProxy
sleep 1
echo -e "[ ${GREEN}ok${NC} ] Restart & Xray & Nginx & HAProxy"
systemctl daemon-reload >/dev/null 2>&1
systemctl restart xray >/dev/null 2>&1
systemctl restart nginx >/dev/null 2>&1
systemctl restart haproxy >/dev/null 2>&1

# Output the NEW UUID and Ports
echo ""
echo "========================================================"
echo "   INSTALLATION COMPLETED - IMPORTANT INFORMATION"
echo "========================================================"
echo "   UUID         : $uuid"
echo "   Vless Port   : $vless"
echo "   Vmess Port   : $vmess"
echo "   Trojan Port  : $trojanws"
echo "   Domain       : $domain"
echo "========================================================"
echo "   NOTE: Please update your client with this NEW UUID!"
echo "   NOTE: If services are still OFF, check /var/log/xray/error.log"
echo "========================================================"

# Final check
sleep 3
if ! systemctl is-active --quiet xray; then
    echo -e "${RED}ERROR: Xray failed to start! Checking logs...${NC}"
    journalctl -u xray --no-pager -n 20
else
    echo -e "${GREEN}SUCCESS: Xray is running.${NC}"
fi

