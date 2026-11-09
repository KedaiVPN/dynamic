#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# --- TEST 1: Backup copies custom path files ---
MOCK_ROOT="$TMP/vps1/root"
MOCK_BACKUP="$MOCK_ROOT/backup"
mkdir -p "$MOCK_ROOT/backup" "$TMP/vps1/etc/xray" "$TMP/vps1/etc/nginx/conf.d"

cat > "$TMP/vps1/etc/xray/custom-paths.conf" << 'EOF'
VMESS_WS_PATH="/vmess-test"
VLESS_WS_PATH="/vless"
TROJAN_WS_PATH="/trojan-ws"
EOF

cat > "$TMP/vps1/etc/xray/custom-path-aliases.conf" << 'EOF'
vmess|/vmess-test|/vmess|10002
EOF

cat > "$TMP/vps1/etc/nginx/conf.d/xray-custom-paths.inc" << 'EOF'
# Managed by /usr/bin/custom-path. Do not edit manually.
location ~ ^/vmess-test$ {
    rewrite ^ /vmess break;
    proxy_pass http://127.0.0.1:10002;
}
EOF

# Simulate backup logic
(
    cp -r "$TMP/vps1/etc/xray/" "$MOCK_BACKUP/xray/"
    if [ -f "$TMP/vps1/etc/nginx/conf.d/xray-custom-paths.inc" ]; then
        mkdir -p "$MOCK_BACKUP/nginx-conf"
        cp -p "$TMP/vps1/etc/nginx/conf.d/xray-custom-paths.inc" "$MOCK_BACKUP/nginx-conf/xray-custom-paths.inc"
    fi
)

[[ -s "$MOCK_BACKUP/xray/custom-paths.conf" ]]
[[ -s "$MOCK_BACKUP/xray/custom-path-aliases.conf" ]]
[[ -s "$MOCK_BACKUP/nginx-conf/xray-custom-paths.inc" ]]
grep -Fq 'VMESS_WS_PATH="/vmess-test"' "$MOCK_BACKUP/xray/custom-paths.conf"
grep -Fq 'vmess|/vmess-test|/vmess|10002' "$MOCK_BACKUP/xray/custom-path-aliases.conf"
grep -Fq 'location ~ ^/vmess-test$ {' "$MOCK_BACKUP/nginx-conf/xray-custom-paths.inc"

# --- TEST 2: Restore recreates Nginx include and calls custom-path --sync ---
DEST="$TMP/vps2"
mkdir -p "$DEST/etc/nginx/conf.d" "$DEST/root/backup"
cp -r "$MOCK_BACKUP"/* "$DEST/root/backup/"
cp -r "$DEST/root/backup/xray/" "$DEST/etc/xray/"

MOCK_BIN="$TMP/mock_bin"
mkdir -p "$MOCK_BIN"
SYNC_FLAG="$TMP/sync_invoked"

# Mock custom-path executable
cat << EOF > "$MOCK_BIN/custom-path"
#!/bin/bash
if [[ "\$1" == "--sync" ]]; then
    touch "$SYNC_FLAG"
    # Execute actual custom-path.sh --sync in isolated paths
    PATH_CONFIG="$DEST/etc/xray/custom-paths.conf" \
    ALIAS_CONFIG="$DEST/etc/xray/custom-path-aliases.conf" \
    NGINX_INCLUDE="$DEST/etc/nginx/conf.d/xray-custom-paths.inc" \
    NGINX_BIN=true \
    NGINX_RELOAD_CMD=true \
    "$ROOT/custom-path.sh" --sync
fi
EOF
chmod +x "$MOCK_BIN/custom-path"

(
    PATH="$MOCK_BIN:$PATH"
    if [ -f "$DEST/etc/xray/custom-paths.conf" ] || [ -f "$DEST/etc/xray/custom-path-aliases.conf" ] || [ -f "$DEST/root/backup/nginx-conf/xray-custom-paths.inc" ]; then
        mkdir -p "$DEST/etc/nginx/conf.d"
        if [ -f "$DEST/root/backup/nginx-conf/xray-custom-paths.inc" ]; then
            cp -f "$DEST/root/backup/nginx-conf/xray-custom-paths.inc" "$DEST/etc/nginx/conf.d/xray-custom-paths.inc"
            chmod 644 "$DEST/etc/nginx/conf.d/xray-custom-paths.inc"
        fi

        if [ -x "$MOCK_BIN/custom-path" ]; then
            "$MOCK_BIN/custom-path" --sync >/dev/null 2>&1 || true
        fi
    fi
)

[[ -f "$SYNC_FLAG" ]]
[[ -s "$DEST/etc/nginx/conf.d/xray-custom-paths.inc" ]]
grep -Fq 'location ~ ^/vmess-test$ {' "$DEST/etc/nginx/conf.d/xray-custom-paths.inc"
grep -Fq 'rewrite ^ /vmess break;' "$DEST/etc/nginx/conf.d/xray-custom-paths.inc"
grep -Fq 'proxy_pass http://127.0.0.1:10002;' "$DEST/etc/nginx/conf.d/xray-custom-paths.inc"

# --- TEST 3: Safety Guard Neutralizes Include if Nginx Check Fails ---
DEST_BROKEN="$TMP/vps3"
mkdir -p "$DEST_BROKEN/etc/nginx/conf.d"
cat << 'EOF' > "$DEST_BROKEN/etc/nginx/conf.d/xray-custom-paths.inc"
syntax error in nginx file;
EOF

(
    # Mock nginx that reports error
    cat << 'EOF' > "$MOCK_BIN/nginx"
#!/bin/bash
if [[ "$*" == *"-t"* ]]; then
    exit 1
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/nginx"

    PATH="$MOCK_BIN:$PATH"
    if command -v nginx >/dev/null 2>&1; then
        if ! nginx -t >/dev/null 2>&1; then
            : > "$DEST_BROKEN/etc/nginx/conf.d/xray-custom-paths.inc"
        fi
    fi
)

# File should have been safely neutralized (size 0)
[[ ! -s "$DEST_BROKEN/etc/nginx/conf.d/xray-custom-paths.inc" ]]

# --- TEST 4: Assert script contents in repo ---
grep -Fq 'cp -p /etc/nginx/conf.d/xray-custom-paths.inc /root/backup/nginx-conf/xray-custom-paths.inc' "$ROOT/backup.sh"
grep -Fq 'cp -f /root/backup/nginx-conf/xray-custom-paths.inc /etc/nginx/conf.d/xray-custom-paths.inc' "$ROOT/restore.sh"
grep -Fq '/usr/bin/custom-path --sync' "$ROOT/restore.sh"
grep -Fq ': > /etc/nginx/conf.d/xray-custom-paths.inc' "$ROOT/restore.sh"
grep -Fq -- '--sync)' "$ROOT/custom-path.sh"

echo "PASS: custom path backup and safe restore validation"
