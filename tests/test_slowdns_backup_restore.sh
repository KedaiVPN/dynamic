#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- TEST 1: Backup copies SlowDNS keys from /root/slowdns ---
MOCK_ROOT="$TMP/vps1/root"
MOCK_BACKUP="$MOCK_ROOT/backup"
mkdir -p "$MOCK_ROOT/slowdns"
printf '%064d\n' 1 > "$MOCK_ROOT/slowdns/server.key"
printf '%064d\n' 2 > "$MOCK_ROOT/slowdns/server.pub"

# Run snippet from backup.sh in mock environment
(
    if [ -f "$MOCK_ROOT/slowdns/server.key" ] && [ -f "$MOCK_ROOT/slowdns/server.pub" ]; then
        mkdir -p "$MOCK_BACKUP/slowdns"
        cp -p "$MOCK_ROOT/slowdns/server.key" "$MOCK_BACKUP/slowdns/server.key"
        cp -p "$MOCK_ROOT/slowdns/server.pub" "$MOCK_BACKUP/slowdns/server.pub"
    fi
)

[[ -s "$MOCK_BACKUP/slowdns/server.key" ]]
[[ -s "$MOCK_BACKUP/slowdns/server.pub" ]]
[[ "$(cat "$MOCK_BACKUP/slowdns/server.pub")" == "$(printf '%064d' 2)" ]]

# --- TEST 2: Restore to server where SlowDNS is INACTIVE ---
DEST_INACTIVE="$TMP/vps_inactive/root"
mkdir -p "$DEST_INACTIVE"

MOCK_BIN="$TMP/mock_bin"
mkdir -p "$MOCK_BIN"
cat << 'EOF' > "$MOCK_BIN/systemctl"
#!/bin/bash
if [[ "$*" == *"is-active --quiet slowdns.service"* ]]; then
    exit 3 # Inactive
fi
exit 0
EOF
chmod +x "$MOCK_BIN/systemctl"

(
    PATH="$MOCK_BIN:$PATH"
    # Execute restore logic
    if [ -f "$MOCK_BACKUP/slowdns/server.key" ] && [ -f "$MOCK_BACKUP/slowdns/server.pub" ]; then
        mkdir -p "$DEST_INACTIVE/slowdns"
        chmod 700 "$DEST_INACTIVE/slowdns"
        cp -f "$MOCK_BACKUP/slowdns/server.key" "$DEST_INACTIVE/slowdns/server.key"
        cp -f "$MOCK_BACKUP/slowdns/server.pub" "$DEST_INACTIVE/slowdns/server.pub"
        chmod 600 "$DEST_INACTIVE/slowdns/server.key"
        chmod 644 "$DEST_INACTIVE/slowdns/server.pub"

        if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet slowdns.service 2>/dev/null; then
            echo "SHOULD_NOT_RUN" > "$DEST_INACTIVE/error.log"
        fi
    fi
)

[[ -s "$DEST_INACTIVE/slowdns/server.key" ]]
[[ -s "$DEST_INACTIVE/slowdns/server.pub" ]]
[[ "$(cat "$DEST_INACTIVE/slowdns/server.pub")" == "$(printf '%064d' 2)" ]]
[[ ! -f "$DEST_INACTIVE/error.log" ]]

# --- TEST 3: Restore to server where SlowDNS is ACTIVE and has OLD keys ---
DEST_ACTIVE="$TMP/vps_active/root"
mkdir -p "$DEST_ACTIVE/slowdns"
printf '%064d\n' 8 > "$DEST_ACTIVE/slowdns/server.key"
printf '%064d\n' 9 > "$DEST_ACTIVE/slowdns/server.pub"

SYNC_CALLED="$TMP/sync_called"
cat << EOF > "$MOCK_BIN/slowdns"
#!/bin/bash
if [[ "\$1" == "sync" ]]; then
    touch "$SYNC_CALLED"
    exit 0
fi
EOF
chmod +x "$MOCK_BIN/slowdns"

cat << 'EOF' > "$MOCK_BIN/systemctl"
#!/bin/bash
if [[ "$*" == *"is-active --quiet slowdns.service"* ]]; then
    exit 0 # Active
fi
exit 0
EOF
chmod +x "$MOCK_BIN/systemctl"

(
    PATH="$MOCK_BIN:$PATH"
    if [ -f "$MOCK_BACKUP/slowdns/server.key" ] && [ -f "$MOCK_BACKUP/slowdns/server.pub" ]; then
        mkdir -p "$DEST_ACTIVE/slowdns"
        chmod 700 "$DEST_ACTIVE/slowdns"
        cp -f "$MOCK_BACKUP/slowdns/server.key" "$DEST_ACTIVE/slowdns/server.key"
        cp -f "$MOCK_BACKUP/slowdns/server.pub" "$DEST_ACTIVE/slowdns/server.pub"
        chmod 600 "$DEST_ACTIVE/slowdns/server.key"
        chmod 644 "$DEST_ACTIVE/slowdns/server.pub"

        if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet slowdns.service 2>/dev/null; then
            if [ -x "$MOCK_BIN/slowdns" ]; then
                "$MOCK_BIN/slowdns" sync >/dev/null 2>&1 || systemctl restart slowdns.service >/dev/null 2>&1 || true
            else
                systemctl restart slowdns.service >/dev/null 2>&1 || true
            fi
        fi
    fi
)

# Verify keys were overwritten with the restored backup keys (2, not 9)
[[ "$(cat "$DEST_ACTIVE/slowdns/server.pub")" == "$(printf '%064d' 2)" ]]
[[ -f "$SYNC_CALLED" ]]

# --- TEST 4: Assert backup.sh and restore.sh script contents match requirements ---
grep -Fq 'cp -p /root/slowdns/server.key /root/backup/slowdns/server.key' "$ROOT/backup.sh"
grep -Fq 'cp -p /root/slowdns/server.pub /root/backup/slowdns/server.pub' "$ROOT/backup.sh"
grep -Fq 'cp -f /root/backup/slowdns/server.key /root/slowdns/server.key' "$ROOT/restore.sh"
grep -Fq 'cp -f /root/backup/slowdns/server.pub /root/slowdns/server.pub' "$ROOT/restore.sh"
grep -Fq 'systemctl is-active --quiet slowdns.service' "$ROOT/restore.sh"
grep -Fq '/usr/bin/slowdns sync' "$ROOT/restore.sh"

echo "PASS: SlowDNS keypair backup and conditional restore validation"
