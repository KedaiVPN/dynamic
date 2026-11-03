#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

if git grep -n -F 'raw.githubusercontent.com/NevermoreSSH/Blueblue' -- '*.sh' README.md; then
    echo 'FAIL: legacy Blueblue raw URL remains' >&2
    exit 1
fi

if git grep -n -F 'https://t.me/todfix667' -- '*.sh' README.md; then
    echo 'FAIL: legacy Telegram URL remains' >&2
    exit 1
fi

if ! git grep -n -F 'https://monitoring.kedaivpn.my.id' -- backup.sh bbr.sh dns.sh >/dev/null; then
    echo 'FAIL: monitoring URL was not applied to all former Telegram locations' >&2
    exit 1
fi

# These URLs download real external artifacts. They are intentionally preserved.
allowed='NevermoreSSH/(BBRplus|gotop|vnstat|Xcore-custompath|swapram)'
remaining=$(git grep -n -E 'NevermoreSSH' -- '*.sh' README.md || true)
unexpected=$(printf '%s\n' "$remaining" | grep -vE "$allowed" || true)
if [[ -n "$unexpected" ]]; then
    printf 'FAIL: non-dependency NevermoreSSH text remains:\n%s\n' "$unexpected" >&2
    exit 1
fi

echo 'PASS: branding cleanup preserves only active NevermoreSSH dependencies'
