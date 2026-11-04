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
assert_contains slowdns-config.sh 'SLOWDNS_RESOLVER'
assert_contains slowdns-config.sh 'DNS       :'
assert_contains factory-reset.sh '/etc/slowdns'
assert_contains factory-reset.sh 'slowdns disable'
assert_contains setup.sh 'chmod +x /usr/bin/slowdns'
assert_contains update.sh 'update_local_script "update.sh" "/usr/bin/update"'
assert_contains update.sh 'update_library_script "slowdns-config.sh" "/usr/lib/slowdns-config.sh"'

if grep -nE 'config\.json|nginx\.conf|xray\.conf' slowdns.sh >/dev/null; then
    echo 'FAIL: SlowDNS manager must not modify Xray/Nginx configuration' >&2
    exit 1
fi

bash -n slowdns.sh usernew.sh menu-ssh.sh api-modules/api-ssh-create.sh api-modules/api-ssh-trial.sh
bash -n tests/test_slowdns_wiring.sh

echo 'PASS: SlowDNS wiring and route isolation'
