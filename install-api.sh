#!/bin/bash
# Install API Backend and Modules

if [ "${EUID}" -ne 0 ]; then
		echo "Please Run This Script As Root User !"
		exit 1
fi

echo "Installing API Modules..."
mkdir -p /usr/local/bin/api-modules
cp api-modules/*.sh /usr/local/bin/api-modules/
chmod +x /usr/local/bin/api-modules/*.sh

echo "Installing Node.js API..."
mkdir -p /etc/nevermore-api/node
cp -r api/* /etc/nevermore-api/node/
cd /etc/nevermore-api/node
npm install

echo "Setting up Service..."
cp api-backend.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable api-backend
systemctl restart api-backend

echo "API Installation Complete."
echo "Port: 5888"
echo "Don't forget to configure Bot Token in menu!"
