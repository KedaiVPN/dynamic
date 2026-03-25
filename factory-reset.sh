#!/bin/bash
clear && printf '\033[3J'
echo -e "\033[1;91m ╔══════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[1;91m ║                  \033[1;97m\033[4;37m> FACTORY RESET <\033[0m                       \033[1;91m║\033[0m"
echo -e "\033[1;91m ╚══════════════════════════════════════════════════════════╝\033[0m"
echo -e "\033[1;93m PERINGATAN:\033[0m"
echo -e "\033[1;97m Fitur ini akan MENGHAPUS SEMUA AKUN secara permanen.\033[0m"
echo -e "\033[1;97m Ini termasuk akun SSH, VMess, VLess, Trojan, dan SS.\033[0m"
echo -e "\033[1;97m Database limit, kuota, dan history juga akan dikosongkan.\033[0m"
echo -e "\033[1;91m ════════════════════════════════════════════════════════════\033[0m"
echo -e ""
read -p " Apakah Anda YAKIN ingin melanjutkan? [y/N]: " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e ""
    echo -e "\033[1;92m Dibatalkan.\033[0m"
    sleep 1
    menu_features
    exit 0
fi

echo -e ""
echo -e " \033[1;93mMemproses Factory Reset...\033[0m"
sleep 1

# 1. Hapus Semua Akun SSH
echo -e " \033[1;94m[1/5]\033[0m \033[1;97mMenghapus semua akun SSH...\033[0m"
# Mengambil semua username dengan UID >= 1000 kecuali nobody, root (0), dan default user seperti ubuntu
users=$(awk -F: '$3 >= 1000 && $1 != "nobody" && $1 != "ubuntu" && $1 != "root" {print $1}' /etc/passwd)
for user in $users; do
    userdel -f "$user" > /dev/null 2>&1
    rm -rf "/home/$user" > /dev/null 2>&1
done

# 2. Hapus Konfigurasi Xray (VMess, VLess, Trojan, SS)
echo -e " \033[1;94m[2/5]\033[0m \033[1;97mMembersihkan konfigurasi Xray...\033[0m"
if [ -f "/etc/xray/config.json" ]; then
    # Menghapus blok dari komentar marker sampai tanda kurung tutup objek json ( },{ )
    sed -i '/^ *#vms /,/^ *},{/d' /etc/xray/config.json
    sed -i '/^ *#vmsg /,/^ *},{/d' /etc/xray/config.json
    sed -i '/^ *### /,/^ *},{/d' /etc/xray/config.json

    sed -i '/^ *#vls /,/^ *},{/d' /etc/xray/config.json
    sed -i '/^ *#vlsg /,/^ *},{/d' /etc/xray/config.json

    sed -i '/^ *#tr /,/^ *},{/d' /etc/xray/config.json
    sed -i '/^ *#trg /,/^ *},{/d' /etc/xray/config.json

    sed -i '/^ *#ssw /,/^ *},{/d' /etc/xray/config.json
    sed -i '/^ *#sswg /,/^ *},{/d' /etc/xray/config.json
fi

# Membersihkan file json user individual (jika ada)
rm -f /etc/xray/*-tls.json /etc/xray/*-none.json > /dev/null 2>&1

# 3. Kosongkan Database Expired & Trash
echo -e " \033[1;94m[3/5]\033[0m \033[1;97mMengosongkan database expired dan log...\033[0m"
echo "" > /etc/expired-users.db
echo "" > /etc/expired-users-trash.db
echo "" > /root/log-limit.txt

# 4. Kosongkan Limit History dan Kuota Xray
echo -e " \033[1;94m[4/5]\033[0m \033[1;97mMenghapus limit user dan kuota...\033[0m"
echo "" > /etc/ssh/limit-user.conf
if [ -d "/etc/xray/limit" ]; then
    echo "" > /etc/xray/limit/vmess
    echo "" > /etc/xray/limit/vless
    echo "" > /etc/xray/limit/trojan
    echo "" > /etc/xray/limit/lock-vmess
    echo "" > /etc/xray/limit/lock-vless
    echo "" > /etc/xray/limit/lock-trojan
    echo "" > /etc/xray/limit/usage-vmess
    echo "" > /etc/xray/limit/usage-vless
    echo "" > /etc/xray/limit/usage-trojan
fi

# Hapus config individual di public_html
rm -f /home/vps/public_html/*.txt > /dev/null 2>&1

# 5. Restart Services
echo -e " \033[1;94m[5/5]\033[0m \033[1;97mMerestart layanan sistem...\033[0m"
systemctl restart xray > /dev/null 2>&1
systemctl restart ssh > /dev/null 2>&1
systemctl restart sshd > /dev/null 2>&1
systemctl restart dropbear > /dev/null 2>&1

echo -e ""
echo -e " \033[1;92mFactory Reset SELESAI!\033[0m"
echo -e " \033[1;97mSemua akun telah berhasil dihapus.\033[0m"
echo -e ""
read -n 1 -s -r -p " Tekan tombol apapun untuk kembali ke menu features..."
menu_features
