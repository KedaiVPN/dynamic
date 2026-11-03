#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

assert_contains() {
    local file="$1" needle="$2"
    if ! grep -Fq -- "$needle" "$ROOT/$file"; then
        printf 'FAIL: %s does not contain %s\n' "$file" "$needle" >&2
        exit 1
    fi
}

# Every WS account generator must load the same sanitized runtime path settings.
for file in \
    add-ws.sh add-vless.sh add-tr.sh \
    menu-vmess.sh menu-vless.sh menu-trojan.sh \
    api-modules/api-xray-create.sh api-modules/api-xray-trial.sh; do
    assert_contains "$file" '. /usr/lib/xray-paths.sh'
done

# VMESS values are embedded before Base64 encoding, while VLESS/Trojan values
# are URL parameters. gRPC must remain intentionally unchanged.
assert_contains add-ws.sh '"path": "${VMESS_WS_PATH}"'
assert_contains add-ws.sh 'Path : ${VMESS_WS_PATH}'
assert_contains menu-vmess.sh '"path": "${VMESS_WS_PATH}"'
assert_contains api-modules/api-xray-create.sh '\"path\":\"${VMESS_WS_PATH}\"'
assert_contains api-modules/api-xray-trial.sh '\"path\":\"${VMESS_WS_PATH}\"'

for file in add-vless.sh menu-vless.sh api-modules/api-xray-create.sh api-modules/api-xray-trial.sh; do
    assert_contains "$file" 'path=${VLESS_WS_PATH}'
done

for file in add-tr.sh menu-trojan.sh api-modules/api-xray-create.sh api-modules/api-xray-trial.sh; do
    assert_contains "$file" 'path=${TROJAN_WS_PATH_ENCODED}'
done

echo 'PASS: all WS account generators use active custom paths'
