 <p align="center">


<h2 align="center">
Auto Script Install XRAY/SSH Websocket Service
Mod By NevermoreSSH
<img src="https://img.shields.io/badge/Release-v3.0-red.svg"></h2>

</p> 
<h2 align="center"> Supported Linux Distribution</h2>
<p align="center"><img src="https://d33wubrfki0l68.cloudfront.net/5911c43be3b1da526ed609e9c55783d9d0f6b066/9858b/assets/img/debian-ubuntu-hover.png"width="400"></p> 
<p align="center">
<img src="https://img.shields.io/static/v1?style=for-the-badge&logo=debian&label=Debian%209&message=Stretch&color=purple"> 
<img src="https://img.shields.io/static/v1?style=for-the-badge&logo=debian&label=Debian%2010&message=Buster&color=purple">  
<img src="https://img.shields.io/static/v1?style=for-the-badge&logo=debian&label=Debian%2011&message=bullseye&color=purple"> 
<p align="center">
<img src="https://img.shields.io/static/v1?style=for-the-badge&logo=ubuntu&label=ubuntu%2018.04 LTS&message=Bionic Beaver&color=red"> 
<img src="https://img.shields.io/static/v1?style=for-the-badge&logo=ubuntu&label=ubuntu%2020.04 LTS&message=Focal Fossa&color=red"> 
</p>



<h2 align="center">Network VPN</h2>

<h2 align="center">

![Hits](https://img.shields.io/badge/SSH-Websocket-8020f3?style=for-the-badge&logo=Cloudflare&logoColor=white&edge_flat=false)
![Hits](https://img.shields.io/badge/XRAY-Vmess-f34b20?style=for-the-badge&logo=Cloudflare&logoColor=white&edge_flat=false)
![Hits](https://img.shields.io/badge/XRAY-VLess-f34b20?style=for-the-badge&logo=Cloudflare&logoColor=white&edge_flat=false)
![Hits](https://img.shields.io/badge/XRAY-Trojan-f34b20?style=for-the-badge&logo=Cloudflare&logoColor=white&edge_flat=false)
</h2>

PLEASE MAKE SURE YOUR DOMAIN SETTINGS IN YOUR CLOUDFLARE AS BELOW (SSL/TLS SETTINGS)<br>
<br>

1. Your SSL/TLS encryption mode is Full
2. Enable SSL/TLS Recommender ✅
3. Edge Certificates > Disable Always Use HTTPS (off)

### ♠️rebuild deb 10 selain do

<pre><code>curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh Debian 10 && reboot</code></pre>
### ♠️rebuild deb 11

<pre><code>curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh Debian 11 && reboot</code></pre>
### ♠️rebuild deb 12

<pre><code>curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh Debian 12 && reboot</code></pre>
### ♠️rebuild ubuntu 20.04

<pre><code>curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh Ubuntu 20.04 && reboot</code></pre>
### ♠️rebuild ubuntu 22

<pre><code>curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh Ubuntu 22.04 && reboot</code></pre>
### ♠️rebuild ubuntu 24

<pre><code>curl -O https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh && bash reinstall.sh Ubuntu 24.04 && reboot</code></pre>

♦️ Installation Link <br>

  ```html
wget -q https://raw.githubusercontent.com/KedaiVPN/dynamic/main/setup.sh && chmod +x setup.sh && screen -S setup ./setup.sh
  ```
♦️ Update
```html
wget -q -O update.sh https://raw.githubusercontent.com/KedaiVPN/dynamic/main/update.sh && chmod +x update.sh && ./update.sh
  ```

♦️ Restore Migrasi (Dari Telegram)
```html
wget -qO restore-migrasi.sh https://raw.githubusercontent.com/KedaiVPN/dynamic/main/restore-migrasi.sh && chmod +x restore-migrasi.sh && ./restore-migrasi.sh
```
<b>
<br>

♦️ Clear Ghost Accounts (Hapus Akun Nyangkut/Tidak Terdaftar)
```html
wget -qO clear-ghost.sh https://raw.githubusercontent.com/KedaiVPN/dynamic/main/clear-ghost.sh && chmod +x clear-ghost.sh && ./clear-ghost.sh
```
<b>

[ FITUR & LAYANAN ] <br>
<br>
✅ **SSH & Dropbear:** Port 22, 109, 143<br>
✅ **UDP Custom**<br>
✅ **SSH Websocket TLS & NON-TLS:** Port 443/80<br>
✅ **XRAY Vmess Websocket & gRPC TLS & NON-TLS:** Port 443/80<br>
✅ **XRAY Vless Websocket & gRPC TLS & NON-TLS:** Port 443/80<br>
✅ **XRAY Trojan Websocket & gRPC TLS & NON-TLS:** Port 443/80<br>
✅ **Shadowsocks WS/gRPC:** Port 443<br>
<br>

[ FITUR SISTEM TERINTEGRASI ] <br>
<br>
✅ **HAProxy Load Balancer**<br>
✅ **Vercel License Manager**<br>
✅ **API Backend (Node.js)**<br>
✅ **Auto Backup & Restore (Rclone/Telegram)**<br>
✅ **Auto Delete Expired & Trash Cleaner**<br>
✅ **Auto Kill Multi-Login**<br>
✅ **Xray Quota & Bandwidth Limit**<br>
✅ **Factory Reset**<br>
✅ **TCP & Kernel Optimization**<br>
<br>

[ FITUR LAINNYA ] <br>
<br>
✅ **BBRPLUS 5.15.96** <br>
✅ **BANDWIDTH MONITOR** <br>
✅ **RAM MONITOR** <br>
✅ **DNS CHANGER** <br>
✅ **NETFLIX REGION CHECKER** <br>
✅ **CHECK LOGIN USER** <br>
✅ **CHECK CREATED CONFIG** <br>
✅ **AUTOMATIC CLEAR LOG** <br>
✅ **AUTOMATIC VPS REBOOT** <br>
✅ **VIRTUAL SWAPRAM** <br></br>


```
   [ Service & Port ]
   - OpenSSH                 : 22
   - SSH Websocket           : 80
   - SSH SSL Websocket       : 443
   - Stunnel5                : 447, 777
   - Dropbear                : 109, 143
   - Badvpn                  : 7100-7300
   - Nginx                   : 81
   - XRAY Vmess GRPC         : 443
   - XRAY Vmess TLS          : 443
   - XRAY Vmess None TLS     : 80
   - XRAY Vless GRPC         : 443
   - XRAY Vless TLS          : 443
   - XRAY Vless None TLS     : 80
   - XRAY Trojan GRPC        : 443
   - XRAY Trojan GO          : 443
   - XRAY Trojan WS          : 443
   - Sodosok WS/GRPC         : 443

   [ Server Information & Other Features ]
   - Timezone                : Asia/Jakarta (GMT +7)
   - Fail2Ban                : [ON]
   - Dflate                  : [ON]
   - IPtables                : [ON]
   - Auto-Reboot             : [ON] - 5.00 AM
   - IPv6                    : [OFF/ON]
   - Autoreboot Off          : [ON]
   - Autobackup Data         : [OFF]
   - AutoKill Multi Login User
   - Auto Delete Expired Account
   - Fully automatic script
   - VPS settings
   - Admin Control
   - Restore Data
   - Full Orders For Various Services
```
