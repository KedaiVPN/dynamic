#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MENU="$ROOT/menu4.sh"

assert_contains() {
    local needle="$1"
    grep -Fq -- "$needle" "$MENU" || {
        printf 'FAIL: menu4.sh is missing %q\n' "$needle" >&2
        exit 1
    }
}

# Custom Path begins the right column at 13. Existing feature actions follow
# sequentially through 24, so the visual grid has no unpaired extra row.
assert_contains '[${BIWhite}13${BIRed}]${BIWhite} CUSTOM PATH'
assert_contains '[${BIWhite}14${BIRed}]${BIWhite} WEBMIN'
assert_contains '[${BIWhite}15${BIRed}]${BIWhite} MONITOR SERVER'
assert_contains '[${BIWhite}23${BIRed}]${BIWhite} INSTALL BOT TELE'
assert_contains '[${BIWhite}24${BIRed}]${BIWhite} FACTORY RESET'

assert_contains "13) clear && printf '\\033[3J' ; custom-path ; menu_features ;;"
assert_contains "14) clear && printf '\\033[3J' ; wbm ;;"
assert_contains "15) clear && printf '\\033[3J' ; wget -q -O /tmp/monitor.sh"
assert_contains "23) clear && printf '\\033[3J' ; /usr/local/bin/api-modules/api-bot-manager.sh ;;"
assert_contains "24) clear && printf '\\033[3J' ; factory-reset.sh ;;"

if grep -Fq '[24${BIRed}]${BIWhite} CUSTOM PATH' "$MENU"; then
    echo 'FAIL: Custom Path remains on an unpaired 24th visual row' >&2
    exit 1
fi

echo 'PASS: Features menu places Custom Path at 13 with aligned grid'
