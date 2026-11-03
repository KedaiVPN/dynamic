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

for file in setup.sh update.sh; do
    assert_contains "$file" '/etc/cron.d/clear-xray-limit'
    assert_contains "$file" '0 7 * * * root : > /root/log-xray-limit.txt'
done

# The scoped task must not accidentally schedule clearing SSH lock history.
if grep -Fq '0 7 * * * root : > /root/log-limit.txt' "$ROOT/setup.sh" "$ROOT/update.sh"; then
    echo 'FAIL: 07:00 cleanup touches SSH multi-login history' >&2
    exit 1
fi

echo 'PASS: 07:00 cron clears only Xray bandwidth-lock history'
