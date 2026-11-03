#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/custom-paths.conf" <<'EOF'
VMESS_WS_PATH="/vmess-depa"
VLESS_WS_PATH="/vless-depa"
TROJAN_WS_PATH="/trojan-private"
EOF

output=$(printf 'x\n' | TERM=dumb \
    PATH_CONFIG="$TMP/custom-paths.conf" \
    ALIAS_CONFIG="$TMP/custom-path-aliases.conf" \
    NGINX_INCLUDE="$TMP/xray-custom-paths.inc" \
    "$ROOT/custom-path.sh")
plain_output=$(printf '%s' "$output" | sed -r 's/\x1B\[[0-9;]*[mK]//g')

assert_contains() {
    local haystack="$1" needle="$2"
    if [[ "$haystack" != *"$needle"* ]]; then
        printf 'FAIL: custom path TUI is missing %q\n' "$needle" >&2
        exit 1
    fi
}

# The screen uses Dynamic's established red frame and menu wording.
assert_contains "$output" $'\033[1;91m ╔══════════════════════════════════════════════════════════╗'
assert_contains "$plain_output" '> CUSTOM PATH <'
assert_contains "$plain_output" 'DEFAULT PATH'
assert_contains "$plain_output" '[01] EDIT PATH VMESS'
assert_contains "$plain_output" '[02] EDIT PATH VLESS'
assert_contains "$plain_output" '[03] EDIT PATH TROJAN'
assert_contains "$plain_output" '[04] LIST CUSTOM PATH'
assert_contains "$plain_output" '[ x] BACK TO FEATURES'
assert_contains "$plain_output" 'VMESS  : /vmess'
assert_contains "$plain_output" 'VLESS  : /vless'
assert_contains "$plain_output" 'TROJAN : /trojan-ws'

# Display is informational: it must not show configured active custom paths.
if [[ "$plain_output" == *'/vmess-depa'* || "$plain_output" == *'/vless-depa'* || "$plain_output" == *'/trojan-private'* ]]; then
    echo 'FAIL: TUI displayed active custom paths instead of defaults' >&2
    exit 1
fi

# Every rendered line of the main screen has the exact 61-cell Dynamic frame.
while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    if [[ "$line" == *'║'* || "$line" == *'╗'* || "$line" == *'╣'* || "$line" == *'╝'* ]]; then
        [[ ${#line} -eq 61 ]] || {
            printf 'FAIL: misaligned frame width %s: %q\n' "${#line}" "$line" >&2
            exit 1
        }
    fi
done <<< "$plain_output"

echo 'PASS: custom path TUI matches Dynamic menu style and frame width'
