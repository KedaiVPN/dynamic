#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

assert_contains() {
    local file="$1" needle="$2"
    grep -Fq -- "$needle" "$ROOT/$file" || {
        printf 'FAIL: %s is missing %q\n' "$file" "$needle" >&2
        exit 1
    }
}

for file in menu-vmess.sh menu-vless.sh menu-trojan.sh; do
    assert_contains "$file" '. /usr/lib/xray-account-detail.sh'
    assert_contains "$file" 'xray_account_detail_lookup'
    if grep -Fq "if [ -f \"/home/vps/public_html/" "$ROOT/$file"; then
        echo "FAIL: $file still treats public .txt as required detail source" >&2
        exit 1
    fi
done

assert_contains menu-vmess.sh 'vmess_tls_link="vmess://$(printf '\''%s'\'' "$json_tls" | base64 -w 0)"'
assert_contains menu-vmess.sh 'VMESS_WS_PATH'
assert_contains menu-vless.sh 'path=${VLESS_WS_PATH}'
assert_contains menu-trojan.sh 'path=${TROJAN_WS_PATH_ENCODED}'

echo 'PASS: detail menus regenerate from Xray account source'
