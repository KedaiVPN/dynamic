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

python3 - <<'PY'
import re
from pathlib import Path

# Verify SSH menu frame width
lines = Path('menu-ssh.sh').read_text().splitlines()
frame = lines[645:661]
visible = []
for line in frame:
    quoted = re.findall(r'"(.*)"', line)
    if not quoted:
        continue
    text = quoted[-1]
    text = re.sub(r'\$\{?\w+\}?', '', text)
    text = re.sub(r'\\033\[[0-9;]*m', '', text)
    visible.append((line, len(text)))
widths = {width for _, width in visible}
assert widths == {56}, f'SSH menu frame has uneven display widths: {visible}'

# Verify SlowDNS menu frame width
sd_lines = Path('slowdns.sh').read_text().splitlines()
menu_idx = next(i for i, l in enumerate(sd_lines) if 'menu()' in l)
frame_sd = [l for l in sd_lines[menu_idx:menu_idx+30] if 'echo -e "${BIRed}' in l and any(c in l for c in '╔║╠╚')]
visible_sd = []
for line in frame_sd:
    quoted = re.findall(r'"(.*)"', line)
    if not quoted:
        continue
    text = quoted[-1]
    text = re.sub(r'\$\{?\w+\}?', '', text)
    text = re.sub(r'\\033\[[0-9;]*m', '', text)
    visible_sd.append((line, len(text)))
widths_sd = {width for _, width in visible_sd}
assert widths_sd == {56}, f'SlowDNS menu frame has uneven display widths: {visible_sd}'
PY

assert_contains slowdns.sh '${BIRed} ╔═════════════════════════════════════════════════════╗${NC}'
assert_contains slowdns.sh '${BIRed} ║                  ${BIWhite}${UWhite}> SLOWDNS MENU <${NC}                   ${BIRed}║${NC}'
assert_contains slowdns.sh '${BIRed} ║   ${BIRed}[${BIWhite} 1${BIRed}]${BIWhite} Aktifkan SlowDNS                             ${BIRed}║${NC}'
assert_contains usernew.sh 'slowdns_load_config'
assert_contains menu-ssh.sh 'slowdns_load_config'
assert_contains api-modules/api-ssh-create.sh 'slowdns_json_fields'
assert_contains api-modules/api-ssh-trial.sh 'slowdns_json_fields'
assert_contains slowdns.sh 'SLOWDNS_BIN=${SLOWDNS_BIN:-$SLOWDNS_DIR/slowdns}'
assert_contains slowdns.sh 'SLOWDNS_BINARY_SHA256='
assert_contains slowdns.sh 'SLOWDNS_BINARY_URL='
assert_contains slowdns.sh 'SLOWDNS_UDP_ADDR'
assert_contains slowdns.sh 'slowdns-linux-amd64'
[[ -f slowdns-linux-amd64 ]]
[[ ! -e slowdns-linux-amd64.tar.gz ]]
[[ "$(sha256sum slowdns-linux-amd64 | awk '{print $1}')" == 'a9d19e39ae23261628e8f21dac79548b31dceb45f959017bc50300e7ebfcad7d' ]]

if grep -nE 'SLOWDNS_PACKAGE|tar -xzf|slowdns-linux-amd64\.tar\.gz' slowdns.sh >/dev/null; then
    echo 'FAIL: manager must distribute only the audited runtime binary, not the vendor archive/installer bundle' >&2
    exit 1
fi

if git ls-files --error-unmatch slowdns-linux-amd64.tar.gz >/dev/null 2>&1; then
    echo 'FAIL: repository must not track the vendor SlowDNS archive bundle' >&2
    exit 1
fi

git ls-files --error-unmatch slowdns-linux-amd64 >/dev/null

git check-ignore -q slowdns-linux-amd64 && {
    echo 'FAIL: official runtime binary is ignored instead of tracked' >&2
    exit 1
} || true

git check-ignore -q slowdns-linux-amd64.tar.gz || true

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
assert_contains factory-reset.sh 'slowdns-watchdog.timer'
assert_contains setup.sh 'chmod +x /usr/bin/slowdns'

if grep -nE '(/usr/bin/slowdns|slowdns)[[:space:]]+(enable|on)' setup.sh >/dev/null; then
    echo 'FAIL: fresh installation must not auto-enable SlowDNS' >&2
    exit 1
fi
assert_contains update.sh 'update_local_script "update.sh" "/usr/bin/update"'
assert_contains update.sh 'update_library_script "slowdns-config.sh" "/usr/lib/slowdns-config.sh"'
assert_contains update.sh '/usr/bin/slowdns sync-watchdog'

if grep -nE '(/usr/bin/slowdns|slowdns)[[:space:]]+(enable|on)' update.sh >/dev/null; then
    echo 'FAIL: updater must not auto-enable or migrate SlowDNS' >&2
    exit 1
fi

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
