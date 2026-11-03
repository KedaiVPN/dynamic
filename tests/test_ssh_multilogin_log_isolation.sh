#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
XRAY_LIMIT="$ROOT/xray-limit.sh"
SSH_MENU="$ROOT/menu-ssh.sh"
UPDATER="$ROOT/update.sh"

assert_contains() {
    local file="$1" needle="$2"
    grep -Fq -- "$needle" "$file" || {
        printf 'FAIL: %s is missing %q\n' "$file" "$needle" >&2
        exit 1
    }
}

# Bandwidth and SSH multi-login histories must never share a writable log.
assert_contains "$XRAY_LIMIT" 'limit_log="/root/log-xray-limit.txt"'
assert_contains "$SSH_MENU" 'ssh_log="/root/log-limit.txt"'
assert_contains "$SSH_MENU" "awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2} .* - .* - [0-9]+ IPs \\(Limit: [0-9]+\\) - LOCKED$/' \"\$ssh_log\""

# A user already listed in lock-<protocol> must be skipped before bandwidth
# stats are evaluated, preventing repeated lock records every cron run.
assert_contains "$XRAY_LIMIT" 'if awk -v u="$user" '\''$1==u { found=1; exit } END { exit !found }'\'' "$lock_file"; then'
assert_contains "$XRAY_LIMIT" 'continue'

# Existing servers receive the fix when they run update.
assert_contains "$UPDATER" 'update_local_script "xray-limit.sh" "/usr/bin/xray-limit"'
assert_contains "$UPDATER" 'update_local_script "menu-ssh.sh" "/usr/bin/menu-ssh"'
assert_contains "$UPDATER" 'update_local_script "tendang.sh" "/usr/bin/tendang"'

# SSH lock history is appended only on the transition to a locked account.
TENDANG="$ROOT/tendang.sh"
assert_contains "$TENDANG" '# Only record a violation when this run actually locks the user.'
locked_line=$(grep -n 'grep -q "L"' "$TENDANG" | head -n1 | cut -d: -f1)
log_line=$(grep -n 'LOCKED" >> "$LOG_FILE"' "$TENDANG" | head -n1 | cut -d: -f1)
[[ "$log_line" -gt "$locked_line" ]] || {
    echo 'FAIL: SSH lock history is written before the already-locked guard' >&2
    exit 1
}

# Filtering legacy mixed logs must retain SSH events and reject Xray bandwidth events.
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT
cat > "$TMP" <<'EOF'
2026-11-03 10:00:00 - sshuser - 3 IPs (Limit: 1) - LOCKED
2026-09-29 08:25:02 vmess HeraBlkSg1VM412 locked (limit 200 GB)
EOF
filtered=$(awk '/^[0-9]{4}-[0-9]{2}-[0-9]{2} .* - .* - [0-9]+ IPs \(Limit: [0-9]+\) - LOCKED$/' "$TMP")
[[ "$filtered" == *'sshuser'* ]] || { echo 'FAIL: valid SSH lock record was filtered out' >&2; exit 1; }
[[ "$filtered" != *'HeraBlkSg1VM412'* ]] || { echo 'FAIL: VMESS bandwidth record leaked into SSH output' >&2; exit 1; }

echo 'PASS: SSH multi-login log is isolated from Xray bandwidth locks'
