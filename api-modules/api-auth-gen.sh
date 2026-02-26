#!/bin/bash
# Generate API Auth Key and send to Telegram

if [[ ! -f /etc/nevermore-api/bot.conf ]]; then
    echo "Error: Bot configuration not found. Please run 'Install Bot Tele' first."
    read -n 1 -s -r -p "Press any key to continue"
    exit 1
fi

source /etc/nevermore-api/bot.conf

if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
    echo "Error: Invalid bot configuration."
    exit 1
fi

# Generate Key
key=$(openssl rand -hex 32)
echo "$key" > /etc/nevermore-api/auth.key
chmod 600 /etc/nevermore-api/auth.key

# Send to Telegram
msg="<b>New API Auth Key Generated</b>%0A%0AKey: <code>$key</code>%0A%0AUse this key to authenticate your API requests."
res=$(curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="$msg" -d parse_mode="HTML")

echo ""
if [[ "$res" == *"\"ok\":true"* ]]; then
    echo "Success! Auth Key sent to your Telegram."
else
    echo "Failed to send message to Telegram."
    echo "Response: $res"
fi
echo ""
read -n 1 -s -r -p "Press any key to continue"
