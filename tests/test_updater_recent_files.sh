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

assert_contains 'github_file_changed_within_days()'
assert_contains 'DYNAMIC_UPDATE_DAYS=3'
assert_contains 'github_file_changed_within_days "$script_name"'
assert_contains 'python3 -m py_compile "$tmp_file"'
assert_contains 'update_local_script "ram.sh" "/usr/bin/cek-ram" python'
assert_contains 'bash -n "$tmp_file"'
assert_contains 'source unavailable; existing file was kept.'
assert_contains 'validation failed; existing file was kept.'

# These paths do not exist in the repository and must not be requested by update.sh.
if grep -Fq 'update_local_script "cek-ram.sh"' "$UPDATER" || \
   grep -Fq 'update_local_script "bckpbot.sh"' "$UPDATER"; then
    echo 'FAIL: updater requests source files absent from repository' >&2
    exit 1
fi

# The real RAM source is Python despite its .sh filename.
assert_contains 'update_local_script "ram.sh" "/usr/bin/cek-ram"'

bash -n "$UPDATER"
python3 -m py_compile "$ROOT/ram.sh"
bash -n "$ROOT/limit-speed.sh"

echo 'PASS: updater uses three-day freshness and type-aware validation'
