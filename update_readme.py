import re

with open('README.md', 'r') as f:
    content = f.read()

# Replace "Services" with Indonesian text and expand the features
services_replacement = """[ FITUR & LAYANAN ] <br>
<br>
✅ **SSH & Dropbear:** Port 22, 109, 143 (Teroptimasi dengan pemfilteran khusus)<br>
✅ **UDP Custom:** Integrasi penuh ePro udp-custom untuk aplikasi HTTP Custom<br>
✅ **SSH Websocket TLS & NON-TLS:** Port 443/80<br>
✅ **XRAY Vmess Websocket & gRPC TLS & NON-TLS:** Port 443/80<br>
✅ **XRAY Vless Websocket & gRPC TLS & NON-TLS:** Port 443/80<br>
✅ **XRAY Trojan Websocket & gRPC TLS & NON-TLS:** Port 443/80<br>
✅ **Shadowsocks WS/gRPC:** Port 443<br>
<br>

[ FITUR SISTEM TERINTEGRASI ] <br>
<br>
✅ **HAProxy Load Balancer:** Konfigurasi tingkat tinggi untuk mendistribusikan trafik port 443 dengan pencegahan timeout & 521 error.<br>
✅ **Vercel License Manager:** Sistem verifikasi lisensi dinamis berbasis API webhook (Express API & Turso DB) untuk keamanan instalasi dan perlindungan script.<br>
✅ **API Backend (Node.js):** REST API Server terpadu untuk integrasi bot Telegram (Mini App), remote update, cek status, dan pengelolaan otomatis.<br>
✅ **Auto Backup & Restore (Rclone/Telegram):** Fitur Autobackup multi-drive (Load Balancing) yang terhubung ke Google Drive, dan pengiriman otomatis via Telegram Bot jika GDrive terkena limit API.<br>
✅ **Auto Delete Expired & Trash Cleaner:** Presisi menghapus akun (SSH & Xray) yang telah kedaluwarsa tanpa merusak database `config.json`.<br>
✅ **Auto Kill Multi-Login (tendang.sh):** Melacak dan mengunci (lock) secara real-time akun yang melanggar batas jumlah login/device.<br>
✅ **Xray Quota & Bandwidth Limit:** Pembatasan presisi untuk pengguna Xray per GB.<br>
✅ **Factory Reset:** Wipe/Pembersihan total seluruh akun dan riwayat VPN seperti state instalasi baru.<br>
✅ **TCP & Kernel Optimization:** Pencegahan port exhaustion & internet timeout dengan tuning agresif pada sysctl.<br>
<br>

[ FITUR LAINNYA ] <br>
<br>
✅ BBRPLUS 5.15.96 <br>
✅ BANDWIDTH MONITOR <br>
✅ RAM MONITOR <br>
✅ DNS CHANGER <br>
✅ NETFLIX REGION CHECKER <br>
✅ CHECK LOGIN USER <br>
✅ CHECK CREATED CONFIG <br>
✅ AUTOMATIC CLEAR LOG <br>
✅ AUTOMATIC VPS REBOOT <br>
✅ VIRTUAL SWAPRAM <br></br>"""

content = re.sub(r'\[ SERVICES \].*?✅ VIRTUAL SWAPRAM <br></br>', services_replacement, content, flags=re.DOTALL)

with open('README.md', 'w') as f:
    f.write(content)
