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

# Maintained files are back in the static update list with type-aware validation.
assert_contains 'update_local_script "ram.sh" "/usr/bin/cek-ram" python'
assert_contains 'update_local_script "limit-speed.sh" "/usr/bin/limit-speed" bash'

# bckpbot.sh has no source in the repository or available history, so it must
# not be requested until a valid source file is added.
if grep -Fq -- 'update_local_script "bckpbot.sh"' "$UPDATER"; then
    echo 'FAIL: updater requests nonexistent bckpbot.sh' >&2
    exit 1
fi
if grep -Fq -- 'DYNAMIC_UPDATE_DAYS' "$UPDATER" || \
   grep -Fq -- 'github_file_changed_within_days' "$UPDATER"; then
    echo 'FAIL: runtime date/API update window remains in updater' >&2
    exit 1
fi

bash -n "$UPDATER"
python3 -m py_compile "$ROOT/ram.sh"
bash -n "$ROOT/limit-speed.sh"

echo 'PASS: updater statically refreshes maintained Python and Bash files'
