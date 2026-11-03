#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

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

# Match Dynamic's established red box, bright-white heading, and numbered style.
assert_contains "$output" $'\033[1;91m ╔══════════════════════════════════════════════════════════╗'
assert_contains "$plain_output" '> CUSTOM PATH <'
assert_contains "$plain_output" '[01] EDIT PATH VMESS'
assert_contains "$plain_output" '[02] EDIT PATH VLESS'
assert_contains "$plain_output" '[03] EDIT PATH TROJAN'
assert_contains "$plain_output" '[04] LIST CUSTOM PATH'
assert_contains "$plain_output" '[ x] BACK TO FEATURES'
assert_contains "$plain_output" 'ACTIVE PATH CONFIGURATION'
assert_contains "$plain_output" 'VMESS  : /vmess'
assert_contains "$plain_output" 'VLESS  : /vless'
assert_contains "$plain_output" 'TROJAN : /trojan-ws'

echo 'PASS: custom path TUI matches Dynamic menu style'
