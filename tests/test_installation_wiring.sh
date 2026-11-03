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
assert_contains update.sh 'update_local_script "custom-path.sh" "/usr/bin/custom-path"'
assert_contains update.sh 'mv "$tmp_xray_paths" /usr/lib/xray-paths.sh'

# The Features menu exposes the locally installed manager, not an external URL.
assert_contains menu4.sh 'CUSTOM PATH'
assert_contains menu4.sh '; custom-path ;'

echo 'PASS: installation, update, and menu wiring'
