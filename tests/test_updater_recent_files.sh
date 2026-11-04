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

# These scripts are intentionally not part of the static update list. They
# are not being actively maintained in this update cycle and previously caused
# false errors (Python checked as Bash, broken legacy shell, missing source).
for forbidden in \
    'update_local_script "ram.sh"' \
    'update_local_script "limit-speed.sh"' \
    'update_local_script "bckpbot.sh"' \
    'DYNAMIC_UPDATE_DAYS' \
    'github_file_changed_within_days'; do
    if grep -Fq -- "$forbidden" "$UPDATER"; then
        printf 'FAIL: update.sh still contains forbidden updater entry %q\n' "$forbidden" >&2
        exit 1
    fi
done

# The sources themselves remain valid for fresh-install/use outside update.sh.
bash -n "$UPDATER"
python3 -m py_compile "$ROOT/ram.sh"
bash -n "$ROOT/limit-speed.sh"

echo 'PASS: updater uses a static list and skips inactive legacy files'
