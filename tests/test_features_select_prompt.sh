#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
MENU="$ROOT/menu4.sh"

if ! grep -Fq 'read -p " Select menu [Type x to menu]: " opt_feat' "$MENU"; then
    echo 'FAIL: Features menu does not show the requested x navigation hint' >&2
    exit 1
fi

echo 'PASS: Features menu shows the x navigation hint'
