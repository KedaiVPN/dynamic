const express = require('express');
const cors = require('cors');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = 5888;
const AUTH_FILE = '/etc/nevermore-api/auth.key';
const SCRIPT_DIR = '/usr/local/bin/api-modules';

app.use(cors());
app.use(express.json());

// Authentication Middleware
const authenticate = (req, res, next) => {
    const authKey = req.query.auth;

    if (!authKey) {
        return res.status(401).json({ status: 'error', message: 'Missing auth parameter' });
    }

    try {
        if (!fs.existsSync(AUTH_FILE)) {
            return res.status(500).json({ status: 'error', message: 'Auth key not configured on server' });
        }
        const serverKey = fs.readFileSync(AUTH_FILE, 'utf8').trim();

        if (authKey !== serverKey) {
            return res.status(403).json({ status: 'error', message: 'Invalid auth key' });
        }
        next();
    } catch (err) {
        console.error("Auth Error:", err);
        return res.status(500).json({ status: 'error', message: 'Internal server error during auth' });
    }
};

app.use(authenticate);

// Helper to execute bash script
const runScript = (scriptName, args, res) => {
    const scriptPath = path.join(SCRIPT_DIR, scriptName);
    // Wrap args in quotes to handle spaces if any
    const command = `sudo ${scriptPath} ${args.map(a => `"${a}"`).join(' ')}`;

    console.log(`Executing: ${command}`);

    exec(command, (error, stdout, stderr) => {
        if (error) {
            console.error(`Error executing script: ${error}`);
            console.error(`Stderr: ${stderr}`);
        }

        // Try to find the JSON in stdout
        const lines = stdout.trim().split('\n');
        let jsonResponse = null;

        // Attempt to parse the last line as JSON
        try {
            const lastLine = lines[lines.length - 1];
            jsonResponse = JSON.parse(lastLine);
        } catch (e) {
            // If failed, try to find ANY json block
            try {
                const match = stdout.match(/\{[\s\S]*\}/);
                if (match) {
                    jsonResponse = JSON.parse(match[0]);
                }
            } catch (e2) {
                console.error("Failed to parse JSON response");
            }
        }

        if (jsonResponse) {
            res.json(jsonResponse);
        } else {
            res.status(500).json({
                status: 'error',
                message: 'Script execution failed or returned invalid response',
                debug_stdout: stdout,
                debug_stderr: stderr
            });
        }
    });
};

// --- SSH Endpoints ---

app.get('/createssh', (req, res) => {
    const { user, password, exp, quota, iplimit } = req.query;
    if (!user || !password || !exp) {
        return res.status(400).json({ status: 'error', message: 'Missing required parameters (user, password, exp)' });
    }
    runScript('api-ssh-create.sh', [user, password, exp, quota || 0, iplimit || 0], res);
});

app.get('/renewssh', (req, res) => {
    const { user, exp, quota, iplimit } = req.query;
    if (!user || !exp) {
        return res.status(400).json({ status: 'error', message: 'Missing required parameters (user, exp)' });
    }
    runScript('api-ssh-renew.sh', [user, exp, quota || 0, iplimit || 0], res);
});

app.get('/deletessh', (req, res) => {
    const { user } = req.query;
    if (!user) return res.status(400).json({ status: 'error', message: 'Missing user parameter' });
    runScript('api-ssh-delete.sh', [user], res);
});

app.get('/trialssh', (req, res) => {
    runScript('api-ssh-trial.sh', [], res);
});

app.get('/statusssh', (req, res) => {
    const { user } = req.query;
    if (!user) return res.status(400).json({ status: 'error', message: 'Missing user parameter' });
    runScript('api-ssh-status.sh', [user], res);
});

// --- Xray Endpoints (Vmess, Vless, Trojan) ---

const handleXrayCreate = (protocol, req, res) => {
    const { user, exp, quota, iplimit } = req.query;
    if (!user || !exp) {
        return res.status(400).json({ status: 'error', message: 'Missing required parameters (user, exp)' });
    }
    runScript('api-xray-create.sh', [protocol, user, exp, quota || 0, iplimit || 0], res);
};

const handleXrayRenew = (protocol, req, res) => {
    const { user, exp, quota } = req.query;
    if (!user || !exp || !quota) {
        return res.status(400).json({ status: 'error', message: 'Missing required parameters (user, exp, quota)' });
    }
    runScript('api-xray-renew.sh', [protocol, user, exp, quota], res);
};

const handleXrayDelete = (protocol, req, res) => {
    const { user } = req.query;
    if (!user) return res.status(400).json({ status: 'error', message: 'Missing user parameter' });
    runScript('api-xray-delete.sh', [protocol, user], res);
};

const handleXrayTrial = (protocol, req, res) => {
    runScript('api-xray-trial.sh', [protocol], res);
};

const handleXrayStatus = (protocol, req, res) => {
    const { user } = req.query;
    if (!user) return res.status(400).json({ status: 'error', message: 'Missing user parameter' });
    runScript('api-xray-status.sh', [protocol, user], res);
};

// Vmess
app.get('/createvmess', (req, res) => handleXrayCreate('vmess', req, res));
app.get('/renewvmess', (req, res) => handleXrayRenew('vmess', req, res));
app.get('/deletevmess', (req, res) => handleXrayDelete('vmess', req, res));
app.get('/trialvmess', (req, res) => handleXrayTrial('vmess', req, res));
app.get('/statusvmess', (req, res) => handleXrayStatus('vmess', req, res));

// Vless
app.get('/createvless', (req, res) => handleXrayCreate('vless', req, res));
app.get('/renewvless', (req, res) => handleXrayRenew('vless', req, res));
app.get('/deletevless', (req, res) => handleXrayDelete('vless', req, res));
app.get('/trialvless', (req, res) => handleXrayTrial('vless', req, res));
app.get('/statusvless', (req, res) => handleXrayStatus('vless', req, res));

// Trojan
app.get('/createtrojan', (req, res) => handleXrayCreate('trojan', req, res));
app.get('/renewtrojan', (req, res) => handleXrayRenew('trojan', req, res));
app.get('/deletetrojan', (req, res) => handleXrayDelete('trojan', req, res));
app.get('/trialtrojan', (req, res) => handleXrayTrial('trojan', req, res));
app.get('/statustrojan', (req, res) => handleXrayStatus('trojan', req, res));

app.listen(PORT, () => {
    console.log(`API Server running on port ${PORT}`);
});
