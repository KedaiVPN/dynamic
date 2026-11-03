#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
UPDATER="$ROOT/update.sh"

assert_contains() {
    local needle="$1"
    grep -Fq -- "$needle" "$UPDATER" || {
        printf 'FAIL: update.sh is missing %q\n' "$needle" >&2
        exit 1
    }
}

# Old servers need their installed terminal account generators refreshed. API
# modules are already updated separately; these are normal and trial terminal flows.
assert_contains 'update_local_script "add-ws.sh" "/usr/bin/add-ws"'
assert_contains 'update_local_script "add-vless.sh" "/usr/bin/add-vless"'
assert_contains 'update_local_script "add-tr.sh" "/usr/bin/add-tr"'
assert_contains 'update_local_script "menu-vmess.sh" "/usr/bin/menu-vmess"'
assert_contains 'update_local_script "menu-vless.sh" "/usr/bin/menu-vless"'
assert_contains 'update_local_script "menu-trojan.sh" "/usr/bin/menu-trojan"'

# Updates must validate the downloaded shell script before replacing a running
# server's executable, so a fetch failure cannot silently install an error page.
assert_contains 'bash -n "$tmp_file"'
assert_contains 'mv "$tmp_file" "$target_file"'

echo 'PASS: updater refreshes all terminal custom path generators safely'
