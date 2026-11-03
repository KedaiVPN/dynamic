#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HELPER="$ROOT/xray-account-detail.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/limit"

cat > "$TMP/config.json" <<'EOF'
#vms alice 2030-01-01
},{"id": "11111111-1111-1111-1111-111111111111","alterId": 0,"email": "alice"
#vls bob 2030-02-02
},{"id": "22222222-2222-2222-2222-222222222222","email": "bob"
#tr carol 2030-03-03
},{"password": "33333333-3333-3333-3333-333333333333","email": "carol"
EOF
printf 'alice 11111111-1111-1111-1111-111111111111 2030-01-01 50 2\n' > "$TMP/limit/vmess"
printf 'bob 22222222-2222-2222-2222-222222222222 2030-02-02 60 3\n' > "$TMP/limit/vless"
printf 'carol 33333333-3333-3333-3333-333333333333 2030-03-03 70 4\n' > "$TMP/limit/trojan"
printf 'locked 44444444-4444-4444-4444-444444444444 2030-04-04 80 5\n' > "$TMP/limit/lock-vmess"

lookup() {
    bash -c '. "$1"; xray_account_detail_lookup "$2" "$3" "$4" "$5" || exit $?; printf "%s|%s|%s|%s|%s\\n" "$DETAIL_UUID" "$DETAIL_EXP" "$DETAIL_QUOTA" "$DETAIL_IP_LIMIT" "$DETAIL_STATE"' _ "$HELPER" "$1" "$2" "$TMP/config.json" "$TMP/limit"
}

[[ "$(lookup vmess alice)" == '11111111-1111-1111-1111-111111111111|2030-01-01|50|2|active' ]]
[[ "$(lookup vless bob)" == '22222222-2222-2222-2222-222222222222|2030-02-02|60|3|active' ]]
[[ "$(lookup trojan carol)" == '33333333-3333-3333-3333-333333333333|2030-03-03|70|4|active' ]]
[[ "$(lookup vmess locked)" == '44444444-4444-4444-4444-444444444444|2030-04-04|80|5|locked' ]]
if lookup vmess 'bad/user' >/dev/null 2>&1; then
    echo 'FAIL: unsafe username was accepted' >&2
    exit 1
fi
if lookup vmess absent >/dev/null 2>&1; then
    echo 'FAIL: missing user was accepted' >&2
    exit 1
fi

echo 'PASS: Xray account detail lookup uses config and lock databases'
