#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin" "$TMP/xray/limit"

# Mock executables
cat > "$TMP/bin/getent" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == passwd && "$2" == "slowdns_fixture" ]]
EOF

cat > "$TMP/bin/userdel" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$USERDEL_LOG"
EOF

cat > "$TMP/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/bin/"*

# Create mock Xray config with slowdns_fixture user
# Marker lines in xray config: #vms <user> <date> and #vls <user> <date>
cat > "$TMP/xray/config.json" <<'EOF'
{"log":{},
"inbounds":[],
"outbounds":[],
"#vmess":[]}
#vms slowdns_fixture 1970-01-01
},{"id": "11111111-1111-1111-1111-111111111111","alterId": 0,"email": "slowdns_fixture"
{"inbounds":[]}
#vless":[]}
#vls slowdns_fixture 1970-01-01
},{"id": "11111111-1111-1111-1111-111111111111","email": "slowdns_fixture"
EOF

# Limit files (one record per user)
echo "slowdns_fixture 11111111-1111-1111-1111-111111111111 1970-01-01 0 0" > "$TMP/xray/limit/vmess"
echo "slowdns_fixture 11111111-1111-1111-1111-111111111111 1970-01-01 0 0" > "$TMP/xray/limit/vless"

# expired.db: MUST be "<user> <type> <timestamp>" — timestamp is seconds since epoch
# We use 1 (epoch = 1970-01-01 00:00:01) which is always expired relative to now
echo "slowdns_fixture ssh 1"     > "$TMP/expired.db"
echo "slowdns_fixture vmess 1"  >> "$TMP/expired.db"
echo "slowdns_fixture vless 1"  >> "$TMP/expired.db"
: > "$TMP/trash.db"

PATH="$TMP/bin:$PATH" \
EXP_DB="$TMP/expired.db" \
TRASH_DB="$TMP/trash.db" \
XRAY_CONFIG="$TMP/xray/config.json" \
XRAY_LIMIT_DIR="$TMP/xray/limit" \
USERDEL_LOG="$TMP/userdel.log" \
  bash "$ROOT/xp.sh" > "$TMP/xp.out" 2>&1

# Assert: Xray config markers removed
if grep -Eq '^#v(ms|ls) slowdns_fixture ' "$TMP/xray/config.json"; then
    echo 'FAIL: expired SlowDNS Xray client markers remain' >&2
    exit 1
fi

# Assert: limit files cleaned
if grep -q 'slowdns_fixture' "$TMP/xray/limit/vmess" "$TMP/xray/limit/vless"; then
    echo 'FAIL: expired SlowDNS limit records remain' >&2
    exit 1
fi

# Assert: expired.db cleaned
if grep -q '^slowdns_fixture ' "$TMP/expired.db"; then
    echo 'FAIL: expired SlowDNS records remain active' >&2
    exit 1
fi

# Assert: userdel called (xp.sh invokes: userdel --force <user>)
if ! grep -q 'slowdns_fixture' "$TMP/userdel.log"; then
    echo 'FAIL: expired SlowDNS system user was not deleted' >&2
    exit 1
fi

printf 'PASS: SlowDNS expiry removes SSH, VMess, VLess, and limit state\n'
