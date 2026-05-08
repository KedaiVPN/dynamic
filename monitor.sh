#!/bin/bash
# Script Installasi VPS Monitor (SSE)
# Untuk monitoring CPU, RAM, dan Network secara real-time

# Cek Root
if [ "${EUID}" -ne 0 ]; then
    echo "Please Run This Script As Root User !"
    exit 1
fi

echo -e "\033[0;32m[INFO]\033[0m Menginstal System Monitor (SSE)..."

mkdir -p /etc/vps-monitor
cd /etc/vps-monitor

# Membuat package.json
cat > package.json << 'PKGEOF'
{
  "name": "vps-monitor",
  "version": "1.0.0",
  "description": "VPS Monitor SSE",
  "main": "server.js",
  "dependencies": {
    "cors": "^2.8.5",
    "express": "^4.18.2"
  }
}
PKGEOF

echo -e "\033[0;32m[INFO]\033[0m Menginstall modul Node.js (express, cors)..."
npm install >/dev/null 2>&1

# Membuat server.js
cat > server.js << 'SRVEOF'
const express = require('express');
const cors = require('cors');
const os = require('os');
const fs = require('fs');
const { exec } = require('child_process');

const app = express();
const PORT = 5890;

app.use(cors());

// Variabel Cache untuk vnstat agar tidak membebani CPU
let vnstatCache = { daily: 0, monthly: 0, lastUpdate: 0 };

// Fungsi untuk update data vnstat (Di-run setiap 5 menit saja)
const updateVnstat = () => {
    exec('vnstat --json', (err, stdout) => {
        if (!err && stdout) {
            try {
                const data = JSON.parse(stdout);
                if (data.interfaces && data.interfaces.length > 0) {
                    const iface = data.interfaces[0];

                    // Daily
                    let dailyRx = 0, dailyTx = 0;
                    if (iface.traffic && iface.traffic.day && iface.traffic.day.length > 0) {
                        const today = iface.traffic.day[iface.traffic.day.length - 1];
                        dailyRx = today.rx;
                        dailyTx = today.tx;
                    }

                    // Monthly
                    let monthlyRx = 0, monthlyTx = 0;
                    if (iface.traffic && iface.traffic.month && iface.traffic.month.length > 0) {
                        const thisMonth = iface.traffic.month[iface.traffic.month.length - 1];
                        monthlyRx = thisMonth.rx;
                        monthlyTx = thisMonth.tx;
                    }

                    vnstatCache = {
                        daily: (dailyRx + dailyTx) / (1024 * 1024 * 1024), // dalam GB
                        monthly: (monthlyRx + monthlyTx) / (1024 * 1024 * 1024), // dalam GB
                        lastUpdate: Date.now()
                    };
                }
            } catch (e) {
                console.error("Gagal parse vnstat JSON:", e.message);
            }
        }
    });
};

// Initial call
updateVnstat();
// Update vnstat cache setiap 5 menit (300000 ms)
setInterval(updateVnstat, 300000);

// Fungsi membaca total bytes dari /proc/net/dev (Sangat ringan)
const getNetworkBytes = () => {
    try {
        const lines = fs.readFileSync('/proc/net/dev', 'utf8').split('\n');
        let rxBytes = 0, txBytes = 0;

        lines.forEach(line => {
            if (line.includes(':') && !line.includes('lo:')) { // Abaikan loopback
                const parts = line.split(':')[1].trim().split(/\s+/);
                rxBytes += parseInt(parts[0], 10) || 0; // rx bytes
                txBytes += parseInt(parts[8], 10) || 0; // tx bytes
            }
        });
        return { rx: rxBytes, tx: txBytes };
    } catch (e) {
        return { rx: 0, tx: 0 };
    }
};

let lastNet = getNetworkBytes();
let lastNetTime = Date.now();

// Fungsi kalkulasi CPU (Sangat Ringan) membaca dari /proc/stat
const getCpuUsage = () => {
    try {
        const statData = fs.readFileSync('/proc/stat', 'utf8');
        const cpuLine = statData.split('\n')[0]; // Ambil baris pertama (total cpu)
        const parts = cpuLine.split(/\s+/).slice(1).map(Number);

        const idle = parts[3];
        const total = parts.reduce((acc, val) => acc + val, 0);

        return { idle, total };
    } catch (e) {
        return { idle: 0, total: 0 };
    }
};

let lastCpu = getCpuUsage();

app.get('/api/monitoring/stream', (req, res) => {
    // Set Header untuk SSE (Server-Sent Events)
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    // Loop interval setiap 1 detik untuk mengirim data
    const interval = setInterval(() => {
        // RAM
        const totalMem = os.totalmem();
        const freeMem = os.freemem();
        const usedMem = totalMem - freeMem;

        // CPU
        const currentCpu = getCpuUsage();
        const idleDiff = currentCpu.idle - lastCpu.idle;
        const totalDiff = currentCpu.total - lastCpu.total;
        const cpuUsagePercent = totalDiff === 0 ? 0 : (1 - (idleDiff / totalDiff)) * 100;
        lastCpu = currentCpu;

        // Network Real-time Speed
        const currentNet = getNetworkBytes();
        const currentTime = Date.now();
        const timeDiff = (currentTime - lastNetTime) / 1000; // detik

        let rxSpeed = 0;
        let txSpeed = 0;

        if (timeDiff > 0) {
            rxSpeed = ((currentNet.rx - lastNet.rx) * 8) / (1024 * 1024 * timeDiff); // Mbps
            txSpeed = ((currentNet.tx - lastNet.tx) * 8) / (1024 * 1024 * timeDiff); // Mbps
            // Cegah angka negatif jika counter direset OS
            if(rxSpeed < 0) rxSpeed = 0;
            if(txSpeed < 0) txSpeed = 0;
        }

        lastNet = currentNet;
        lastNetTime = currentTime;

        // Data Payload
        const payload = {
            cpu_usage: cpuUsagePercent.toFixed(1), // persentase
            ram_used: (usedMem / (1024 * 1024)).toFixed(0), // MB
            ram_total: (totalMem / (1024 * 1024)).toFixed(0), // MB
            net_rx_mbps: rxSpeed.toFixed(2), // Mbps
            net_tx_mbps: txSpeed.toFixed(2), // Mbps
            bandwidth_daily_gb: vnstatCache.daily.toFixed(2), // GB
            bandwidth_monthly_gb: vnstatCache.monthly.toFixed(2), // GB
            uptime: os.uptime() // Detik
        };

        // Kirim SSE
        res.write(`data: ${JSON.stringify(payload)}\n\n`);

    }, 1000);

    // Jika koneksi dari client (browser) terputus
    req.on('close', () => {
        clearInterval(interval);
        res.end();
    });
});

app.listen(PORT, () => {
    console.log(`VPS Monitor (SSE) running on port ${PORT}`);
});
SRVEOF

# Setup Systemd Service
cat > /etc/systemd/system/vps-monitor.service << 'SVCEOF'
[Unit]
Description=VPS Monitor SSE Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/etc/vps-monitor
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable vps-monitor
systemctl restart vps-monitor

echo -e "\033[0;32m[OK]\033[0m Instalasi Selesai!"
echo -e "Service 'vps-monitor' berjalan di port 5890."
echo -e "Endpoint SSE: \033[0;36mhttp://$(curl -s ifconfig.me):5890/api/monitoring/stream\033[0m"
echo -e ""
echo -e "Silahkan hubungkan Frontend Vercel Anda ke endpoint di atas."
