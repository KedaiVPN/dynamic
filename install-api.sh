#!/bin/bash
# Install API Backend and Modules
# Updated to download dependencies directly

set -e
# NOTE: Run as root

REPO="https://raw.githubusercontent.com/KedaiVPN/dynamic/main"

download_with_retry() {
    local url="$1"
    local dest="$2"
    local max_attempts="${3:-5}"
    local delay="${4:-2}"
    local tmp_file
    local attempt=1

    mkdir -p "$(dirname "$dest")"
    tmp_file=$(mktemp "${dest}.tmp.XXXXXX") || return 1

    while [ "$attempt" -le "$max_attempts" ]; do
        rm -f "$tmp_file"
        if command -v wget >/dev/null 2>&1; then
            if wget -q --timeout=20 --tries=1 -O "$tmp_file" "$url" && [ -s "$tmp_file" ]; then
                mv -f "$tmp_file" "$dest"
                return 0
            fi
        fi
        rm -f "$tmp_file"
        if command -v curl >/dev/null 2>&1; then
            if curl -fsSL --connect-timeout 15 --max-time 120 -o "$tmp_file" "$url" && [ -s "$tmp_file" ]; then
                mv -f "$tmp_file" "$dest"
                return 0
            fi
        fi
        rm -f "$tmp_file"
        if [ "$attempt" -lt "$max_attempts" ]; then
            sleep "$delay"
        fi
        attempt=$((attempt + 1))
    done
    return 1
}

apt_with_retry() {
    local max_attempts=3
    local attempt=1
    while [ "$attempt" -le "$max_attempts" ]; do
        if DEBIAN_FRONTEND=noninteractive apt-get \
            -o DPkg::Lock::Timeout=120 \
            -o Acquire::Retries=5 \
            -o Acquire::http::Timeout=30 \
            -o Acquire::https::Timeout=30 \
            "$@"; then
            return 0
        fi
        DEBIAN_FRONTEND=noninteractive dpkg --configure -a >/dev/null 2>&1 || true
        DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=120 update -y >/dev/null 2>&1 || true
        attempt=$((attempt + 1))
        sleep 2
    done
    return 1
}

# 1. Install Dependencies
echo "Installing Node.js and dependencies..."
if ! command -v node &> /dev/null; then
    download_with_retry "https://deb.nodesource.com/setup_22.x" "/tmp/nodesource_setup_22.x"
    bash /tmp/nodesource_setup_22.x
    rm -f /tmp/nodesource_setup_22.x
    apt_with_retry install -y nodejs
fi

if ! command -v npm &> /dev/null; then
    apt_with_retry install -y npm
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
    "api-slowdns-create.sh"
    "api-slowdns-renew.sh"
    "api-slowdns-delete.sh"
    "api-slowdns-trial.sh"
    "api-slowdns-status.sh"
    "api-xray-create.sh"
    "api-xray-renew.sh"
    "api-xray-delete.sh"
    "api-xray-trial.sh"
    "api-xray-status.sh"
    "api-bot-manager.sh"
    "api-auth-gen.sh"
)

for file in "${files[@]}"; do
    download_with_retry "${REPO}/api-modules/${file}" "$file"
    chmod +x "$file"
done

# 3. Setup Node.js Application
echo "Setting up Node.js API..."
mkdir -p /etc/nevermore-api/node
cd /etc/nevermore-api/node

# Download API files
download_with_retry "${REPO}/api/server.js" "server.js"
download_with_retry "${REPO}/api/package.json" "package.json"

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
download_with_retry "${REPO}/api/api-backend.service" "api-backend.service"

systemctl daemon-reload
systemctl enable api-backend
systemctl restart api-backend

echo "API Installation Complete."
echo "Port: 5888"
echo "Don't forget to configure Bot Token in menu (Features -> Install Bot Tele)!"
