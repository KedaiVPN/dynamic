import re

with open('README.md', 'r') as f:
    content = f.read()

services_replacement = """[ FITUR & LAYANAN ] <br>
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
✅ **VIRTUAL SWAPRAM** <br></br>"""

content = re.sub(r'\[ FITUR & LAYANAN \].*?✅ VIRTUAL SWAPRAM <br></br>', services_replacement, content, flags=re.DOTALL)

with open('README.md', 'w') as f:
    f.write(content)
