#!/bin/bash
# Interactive script to setup Telegram Bot for API Auth

clear
echo "======================================================="
echo "           Setup Telegram Bot for API Auth             "
echo "======================================================="
echo ""
read -p "Enter Telegram Bot Token: " token
read -p "Enter Telegram User/Chat ID: " chatid

if [[ -z "$token" || -z "$chatid" ]]; then
    echo "Error: Token and Chat ID are required."
    exit 1
fi

mkdir -p /etc/nevermore-api
echo "BOT_TOKEN=$token" > /etc/nevermore-api/bot.conf
echo "CHAT_ID=$chatid" >> /etc/nevermore-api/bot.conf

echo ""
echo "Configuration saved to /etc/nevermore-api/bot.conf"
echo "You can now use 'Generate API Auth Key' from the menu."
read -n 1 -s -r -p "Press any key to continue"
