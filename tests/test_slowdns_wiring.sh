#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

assert_contains() {
    local file="$1" needle="$2"
    grep -Fq -- "$needle" "$file" || {
        printf 'FAIL: %s is missing %q\n' "$file" "$needle" >&2
        exit 1
    }
}

assert_contains setup.sh 'download_or_copy "slowdns.sh" "/usr/bin/slowdns"'
assert_contains setup.sh 'download_or_copy "slowdns-config.sh" "/usr/lib/slowdns-config.sh"'
assert_contains update.sh 'update_local_script "slowdns.sh" "/usr/bin/slowdns"'
assert_contains update.sh 'update_library_script "slowdns-config.sh" "/usr/lib/slowdns-config.sh"'
assert_contains menu-ssh.sh '12) clear && printf '\''\033[3J'\'' ; slowdns ;;'
assert_contains menu-ssh.sh 'SLOWDNS'
assert_contains usernew.sh 'slowdns_load_config'
assert_contains menu-ssh.sh 'slowdns_load_config'
assert_contains api-modules/api-ssh-create.sh 'slowdns_json_fields'
assert_contains api-modules/api-ssh-trial.sh 'slowdns_json_fields'
assert_contains slowdns.sh 'SLOWDNS_BIN=${SLOWDNS_BIN:-$SLOWDNS_DIR/slowdns}'
assert_contains slowdns.sh 'SLOWDNS_BINARY_SHA256='
assert_contains slowdns.sh 'SLOWDNS_BINARY_URL='
assert_contains slowdns.sh 'SLOWDNS_UDP_ADDR'
assert_contains slowdns.sh 'SLOWDNS_NS_DOMAIN=${SLOWDNS_NS_DOMAIN_OVERRIDE:-ns-${domain}}'
assert_contains slowdns.sh '--notrack'
assert_contains slowdns.sh 'udp --dport 1:52'
assert_contains slowdns.sh 'udp --dport 54:65535'
assert_contains slowdns-config.sh 'SLOWDNS_RESOLVER'
assert_contains slowdns-config.sh 'SLOWDNS_DIR:-/root/slowdns'
assert_contains slowdns-config.sh 'SLOWDNS_KEY_FILE=${SLOWDNS_KEY_FILE:-${SLOWDNS_DIR}/server.pub}'
assert_contains slowdns-config.sh 'slowdns_account_fields'
assert_contains slowdns-config.sh 'Pubkey    : %s'
assert_contains slowdns-config.sh 'slowdns.env'
assert_contains factory-reset.sh '/root/slowdns'
assert_contains factory-reset.sh 'slowdns disable'
assert_contains setup.sh 'slowdns enable'
assert_contains setup.sh 'chmod +x /usr/bin/slowdns'
assert_contains update.sh 'update_local_script "update.sh" "/usr/bin/update"'
assert_contains update.sh 'update_library_script "slowdns-config.sh" "/usr/lib/slowdns-config.sh"'
assert_contains update.sh '/usr/bin/slowdns enable'

if grep -nE 'dnstt-server|dnstt\.network|SLOWDNS_INTERNAL_PORT' slowdns.sh >/dev/null; then
    echo 'FAIL: SlowDNS manager still contains legacy DNSTT implementation' >&2
    exit 1
fi
if grep -nE 'config\.json|nginx\.conf|xray\.conf' slowdns.sh >/dev/null; then
    echo 'FAIL: SlowDNS manager must not modify Xray/Nginx configuration' >&2
    exit 1
fi

bash -n slowdns.sh usernew.sh menu-ssh.sh api-modules/api-ssh-create.sh api-modules/api-ssh-trial.sh
bash -n tests/test_slowdns_wiring.sh tests/test_slowdns_fresh_server.sh
bash tests/test_slowdns_fresh_server.sh

echo 'PASS: SlowDNS wiring and route isolation'
