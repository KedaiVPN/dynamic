#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$ROOT/custom-path.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

assert_eq() {
    local expected="$1" actual="$2" message="$3"
    if [[ "$expected" != "$actual" ]]; then
        printf 'FAIL: %s\nexpected: %s\nactual: %s\n' "$message" "$expected" "$actual" >&2
        exit 1
    fi
}

assert_file_contains() {
    local needle="$1" file="$2" message="$3"
    if ! grep -Fqx -- "$needle" "$file"; then
        printf 'FAIL: %s\nmissing: %s\nfile: %s\n' "$message" "$needle" "$file" >&2
        exit 1
    fi
}

# Required feature behavior: valid single-segment paths only.
"$SCRIPT" --validate-path /vmess-lea
"$SCRIPT" --validate-path /vless_01
if "$SCRIPT" --validate-path 'vmess-lea'; then
    echo 'FAIL: accepted path without a leading slash' >&2
    exit 1
fi
if "$SCRIPT" --validate-path '/vmess/extra'; then
    echo 'FAIL: accepted multi-segment path' >&2
    exit 1
fi
if "$SCRIPT" --validate-path '/vmess;include'; then
    echo 'FAIL: accepted unsafe nginx syntax' >&2
    exit 1
fi

# Setting an active VMESS path preserves default settings for other protocols,
# appends its alias, and renders a regex (`location ~`) proxy route.
PATH_CONFIG="$TMP/custom-paths.conf" \
ALIAS_CONFIG="$TMP/custom-path-aliases.conf" \
NGINX_INCLUDE="$TMP/xray-custom-paths.inc" \
NGINX_BIN=true \
NGINX_RELOAD_CMD=true \
"$SCRIPT" --set vmess /vmess-lea

assert_file_contains 'VMESS_WS_PATH="/vmess-lea"' "$TMP/custom-paths.conf" 'VMESS active path was not saved'
assert_file_contains 'VLESS_WS_PATH="/vless"' "$TMP/custom-paths.conf" 'VLESS default was not preserved'
assert_file_contains 'TROJAN_WS_PATH="/trojan-ws"' "$TMP/custom-paths.conf" 'Trojan default was not preserved'
assert_file_contains 'vmess|/vmess-lea|/vmess|10002' "$TMP/custom-path-aliases.conf" 'VMESS alias was not registered'
grep -Fq 'location ~ ^/vmess-lea$ {' "$TMP/xray-custom-paths.inc"
grep -Fq 'rewrite ^ /vmess break;' "$TMP/xray-custom-paths.inc"
grep -Fq 'proxy_pass http://127.0.0.1:10002;' "$TMP/xray-custom-paths.inc"

# A later active path retains the earlier alias for already issued accounts.
PATH_CONFIG="$TMP/custom-paths.conf" \
ALIAS_CONFIG="$TMP/custom-path-aliases.conf" \
NGINX_INCLUDE="$TMP/xray-custom-paths.inc" \
NGINX_BIN=true \
NGINX_RELOAD_CMD=true \
"$SCRIPT" --set vmess /vmess-baru
assert_file_contains 'vmess|/vmess-lea|/vmess|10002' "$TMP/custom-path-aliases.conf" 'Old VMESS alias was removed'
assert_file_contains 'vmess|/vmess-baru|/vmess|10002' "$TMP/custom-path-aliases.conf" 'New VMESS alias was not registered'
grep -Fq 'location ~ ^/vmess-lea$ {' "$TMP/xray-custom-paths.inc"
grep -Fq 'location ~ ^/vmess-baru$ {' "$TMP/xray-custom-paths.inc"

# Cross-protocol conflicts and unsafe paths must be rejected.
if PATH_CONFIG="$TMP/custom-paths.conf" ALIAS_CONFIG="$TMP/custom-path-aliases.conf" NGINX_INCLUDE="$TMP/xray-custom-paths.inc" NGINX_BIN=true NGINX_RELOAD_CMD=true "$SCRIPT" --set vless /vmess-lea; then
    echo 'FAIL: allowed path already owned by another protocol' >&2
    exit 1
fi
if PATH_CONFIG="$TMP/custom-paths.conf" ALIAS_CONFIG="$TMP/custom-path-aliases.conf" NGINX_INCLUDE="$TMP/xray-custom-paths.inc" NGINX_BIN=true NGINX_RELOAD_CMD=true "$SCRIPT" --set trojan /api; then
    echo 'FAIL: allowed reserved path' >&2
    exit 1
fi

echo 'PASS: custom path runtime manager'
