#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MENU="$ROOT/menu4.sh"

# Custom-path is a child executable. Returning from it must re-enter the
# already-running Features function instead of ending menu4.sh at root shell.
if ! grep -Fq "13) clear && printf '\\033[3J' ; custom-path ; menu_features ;;" "$MENU"; then
    echo 'FAIL: option 13 does not return to menu_features after custom-path exits' >&2
    exit 1
fi

echo 'PASS: custom path x navigation returns to Features'
