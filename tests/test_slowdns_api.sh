#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Mock environment setup
mkdir -p "$TMP/slowdns" "$TMP/etc/xray" "$TMP/etc/ssh" "$TMP/bin"
printf 'SLOWDNS_ENABLED="1"\nSLOWDNS_DOMAIN="vps.example.com"\nSLOWDNS_NS_DOMAIN="ns-vps.example.com"\nSLOWDNS_UDP_ADDR="103.150.60.5:53"\nSLOWDNS_RESOLVER="103.150.60.5:53"\n' > "$TMP/slowdns/slowdns.env"
printf '%064d\n' 7 > "$TMP/slowdns/server.pub"

# Mock systemctl and user tools
cat > "$TMP/bin/systemctl" <<'EOF'
#!/bin/bash
if [[ "$*" == *"is-active"* && "$*" == *"slowdns.service"* ]]; then
    exit 0
fi
exit 0
EOF
chmod +x "$TMP/bin/systemctl"

cat > "$TMP/bin/useradd" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$TMP/bin/useradd"

cat > "$TMP/bin/usermod" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$TMP/bin/usermod"

cat > "$TMP/bin/userdel" <<'EOF'
#!/bin/bash
exit 0
EOF
chmod +x "$TMP/bin/userdel"

cat > "$TMP/bin/passwd" <<'EOF'
#!/bin/bash
if [[ "$1" == "-S" ]]; then
    echo "$2 P 2026-01-01 0 99999 7 -1"
    exit 0
fi
exit 0
EOF
chmod +x "$TMP/bin/passwd"

cat > "$TMP/bin/chage" <<'EOF'
#!/bin/bash
echo "Account expires : 2026-12-31"
exit 0
EOF
chmod +x "$TMP/bin/chage"

cat > "$TMP/bin/id" <<'EOF'
#!/bin/bash
if [[ -f "$SLOWDNS_DIR/existing_users" ]] && grep -q "^$1$" "$SLOWDNS_DIR/existing_users"; then
    exit 0
fi
exit 1
EOF
chmod +x "$TMP/bin/id"

export PATH="$TMP/bin:$PATH"
export SLOWDNS_DIR="$TMP/slowdns"
export SLOWDNS_ENV_FILE="$TMP/slowdns/slowdns.env"
export SLOWDNS_KEY_FILE="$TMP/slowdns/server.pub"

# 1. Test Inactive SlowDNS Error
printf 'SLOWDNS_ENABLED="0"\n' > "$TMP/slowdns/slowdns.env"
inactive_out=$(bash "$ROOT/api-modules/api-slowdns-create.sh" "testuser" "secret123" "30" "200" "2" 2>&1 || true)
if [[ "$inactive_out" != *"SlowDNS service is not active"* ]]; then
    echo "FAIL: Expected inactive service error, got: $inactive_out" >&2
    exit 1
fi

# 2. Test Successful Create
printf 'SLOWDNS_ENABLED="1"\nSLOWDNS_DOMAIN="vps.example.com"\nSLOWDNS_NS_DOMAIN="ns-vps.example.com"\nSLOWDNS_UDP_ADDR="103.150.60.5:53"\nSLOWDNS_RESOLVER="103.150.60.5:53"\n' > "$TMP/slowdns/slowdns.env"

# Intercept output
create_out=$(bash "$ROOT/api-modules/api-slowdns-create.sh" "myuser" "pass456" "30" "200" "2")

# Validate JSON with python
python3 - <<PY
import json, sys

data = json.loads('''$create_out''')
assert data["status"] == "success", f"Status not success: {data}"
acc = data["data"]
assert acc["username"].startswith("myuserDNS"), f"Invalid username prefix: {acc['username']}"
assert acc["password"] == "pass456", f"Invalid password: {acc['password']}"
assert acc["domain"] == "vps.example.com", f"Invalid domain: {acc['domain']}"
assert acc["ns_domain"] == "ns-vps.example.com", f"Invalid ns_domain: {acc['ns_domain']}"
assert len(acc["pubkey"]) == 64, f"Invalid pubkey: {acc['pubkey']}"
assert acc["dns"] == "vps.example.com", f"Invalid dns: {acc['dns']}"
assert acc["ip_limit"] == "2", f"Invalid ip_limit: {acc['ip_limit']}"
PY

# 3. Test Trial Create
trial_out=$(bash "$ROOT/api-modules/api-slowdns-trial.sh")
python3 - <<PY
import json, sys

data = json.loads('''$trial_out''')
assert data["status"] == "success", f"Status not success: {data}"
acc = data["data"]
assert acc["username"].startswith("trialDNS"), f"Invalid username prefix: {acc['username']}"
assert acc["domain"] == "vps.example.com", f"Invalid domain: {acc['domain']}"
assert acc["ns_domain"] == "ns-vps.example.com", f"Invalid ns_domain: {acc['ns_domain']}"
assert len(acc["pubkey"]) == 64, f"Invalid pubkey: {acc['pubkey']}"
assert acc["dns"] == "vps.example.com", f"Invalid dns: {acc['dns']}"
assert acc["expired"] == "30 Minutes", f"Invalid expired: {acc['expired']}"
PY

# 4. Test Renew
echo "myuserDNS123" >> "$SLOWDNS_DIR/existing_users"
renew_out=$(bash "$ROOT/api-modules/api-slowdns-renew.sh" "myuserDNS123" "30" "200" "2")
python3 - <<PY
import json

data = json.loads('''$renew_out''')
assert data["status"] == "success", f"Status not success: {data}"
assert "expired" in data["data"]
PY

# 5. Test Delete
delete_out=$(bash "$ROOT/api-modules/api-slowdns-delete.sh" "myuserDNS123")
python3 - <<PY
import json

data = json.loads('''$delete_out''')
assert data["status"] == "success", f"Status not success: {data}"
PY

# 6. Test Status
status_out=$(bash "$ROOT/api-modules/api-slowdns-status.sh" "myuserDNS123")
python3 - <<PY
import json

data = json.loads('''$status_out''')
assert data["status"] == "success", f"Status not success: {data}"
assert data["data"]["protocol"] == "slowdns"
assert data["data"]["username"] == "myuserDNS123"
PY

# 7. Check server.js wiring
grep -Fq "app.get('/createslowdns'" "$ROOT/api/server.js"
grep -Fq "app.get('/renewslowdns'" "$ROOT/api/server.js"
grep -Fq "app.get('/deleteslowdns'" "$ROOT/api/server.js"
grep -Fq "app.get('/trialslowdns'" "$ROOT/api/server.js"
grep -Fq "app.get('/statusslowdns'" "$ROOT/api/server.js"

# 8. Check install-api.sh and update.sh wiring
grep -Fq "api-slowdns-create.sh" "$ROOT/install-api.sh"
grep -Fq "api-slowdns-create.sh" "$ROOT/update.sh"

echo "PASS: SlowDNS API endpoints and modules validation"
