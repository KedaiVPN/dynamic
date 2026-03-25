#!/bin/bash
# Install API Backend and Modules
# Updated to download dependencies directly

if [ "${EUID}" -ne 0 ]; then
    echo "Please Run This Script As Root User !"
    exit 1
fi

REPO="https://raw.githubusercontent.com/KedaiVPN/dynamic/main"

# 1. Install Dependencies
echo "Installing Node.js and dependencies..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
    apt-get install -y nodejs
fi

if ! command -v npm &> /dev/null; then
    apt-get install -y npm
fi

# 2. Download Bash Wrapper Scripts
echo "Downloading API Modules..."
mkdir -p /usr/local/bin/api-modules
cd /usr/local/bin/api-modules
files=(
    "api-ssh-create.sh"
    "api-ssh-renew.sh"
    "api-ssh-delete.sh"
    "api-ssh-trial.sh"
    "api-ssh-status.sh"
    "api-xray-create.sh"
    "api-xray-renew.sh"
    "api-xray-delete.sh"
    "api-xray-trial.sh"
    "api-xray-status.sh"
    "api-bot-manager.sh"
    "api-auth-gen.sh"
)

for file in "${files[@]}"; do
    wget -q -O "$file" "${REPO}/api-modules/${file}"
    chmod +x "$file"
done

# 3. Setup Node.js Application
echo "Setting up Node.js API..."
mkdir -p /etc/nevermore-api/node
cd /etc/nevermore-api/node

# Download API files
wget -q -O server.js "${REPO}/api/server.js"
wget -q -O package.json "${REPO}/api/package.json"

# Install Node modules
if [ -f "package.json" ]; then
    npm install
else
    # Fallback if package.json download fails (create minimal one)
    npm init -y
    npm install express cors dotenv
fi

# 4. Setup Systemd Service
echo "Setting up Service..."
cd /etc/systemd/system/
wget -q -O api-backend.service "${REPO}/api/api-backend.service"

systemctl daemon-reload
systemctl enable api-backend
systemctl restart api-backend

echo "API Installation Complete."
echo "Port: 5888"
echo "Don't forget to configure Bot Token in menu (Features -> Install Bot Tele)!"
