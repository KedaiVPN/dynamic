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

# Nginx's WebSocket server must include generated custom routes in both the
# fresh-install template and the updater template.
assert_contains ins-xray.sh 'include /etc/nginx/conf.d/xray-custom-paths.inc;'
assert_contains update.sh 'include /etc/nginx/conf.d/xray-custom-paths.inc;'

# Fresh installation deploys manager/parser; update refreshes them atomically.
assert_contains setup.sh 'download_or_copy "custom-path.sh" "/usr/bin/custom-path"'
assert_contains setup.sh 'download_or_copy "xray-paths.sh" "/usr/lib/xray-paths.sh"'
assert_contains setup.sh 'download_or_copy "xray-account-detail.sh" "/usr/lib/xray-account-detail.sh"'
assert_contains setup.sh 'download_or_copy "slowdns.sh" "/usr/bin/slowdns"'
assert_contains setup.sh 'download_or_copy "slowdns-config.sh" "/usr/lib/slowdns-config.sh"'

if grep -nE '(/usr/bin/slowdns|slowdns)[[:space:]]+(enable|on)' "$ROOT/setup.sh" >/dev/null; then
    echo 'FAIL: fresh installation must not auto-enable SlowDNS' >&2
    exit 1
fi

assert_contains update.sh 'update_local_script "custom-path.sh" "/usr/bin/custom-path"'
assert_contains update.sh 'update_library_script "xray-account-detail.sh" "/usr/lib/xray-account-detail.sh"'

# The Features menu exposes the locally installed manager, not an external URL.
assert_contains menu4.sh 'CUSTOM PATH'
assert_contains menu4.sh '; custom-path ;'

# BadVPN client limit must be 1000 across installation, updater, and restart scripts,
# running as dedicated systemd template unit (nobody, 1M FD limit, QUIC blocked for nobody).
if grep -q 'max-clients 500' "$ROOT/ssh-vpn.sh"; then
    echo 'FAIL: ssh-vpn.sh must use --max-clients 1000' >&2
    exit 1
fi
if grep -q 'max-clients 500' "$ROOT/restart.sh"; then
    echo 'FAIL: restart.sh must use --max-clients 1000' >&2
    exit 1
fi
if grep -q 'screen -dmS badvpn' "$ROOT/ssh-vpn.sh"; then
    echo 'FAIL: ssh-vpn.sh must not spawn screen-based badvpn' >&2
    exit 1
fi
assert_contains ssh-vpn.sh '--max-clients 1000'
assert_contains restart.sh '--max-clients 1000'
for script in ssh-vpn.sh update.sh; do
    assert_contains "$script" '/etc/systemd/system/badvpn-udpgw@.service'
    assert_contains "$script" 'User=nobody'
    assert_contains "$script" 'LimitNOFILE=1048576'
    assert_contains "$script" '--client-socket-sndbuf 0 --loglevel warning'
    assert_contains "$script" 'badvpn-udpgw@7100 badvpn-udpgw@7200 badvpn-udpgw@7300'
    assert_contains "$script" 'badvpn-block-quic'
done
assert_contains restart.sh 'badvpn-udpgw@7100 badvpn-udpgw@7200 badvpn-udpgw@7300'
for script in setup.sh update.sh; do
    assert_contains "$script" '/usr/local/sbin/enable-rps.sh'
    assert_contains "$script" '/etc/systemd/system/network-rps.service'
done

echo 'PASS: installation, update, and menu wiring'
