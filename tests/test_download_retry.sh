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

# 1. Syntax check across all modified installers and updaters
for script in setup.sh ssh-vpn.sh ins-xray.sh install-api.sh set-br.sh udp-custom.sh vnstat.sh slowdns.sh update.sh bbr.sh restart.sh; do
    bash -n "$ROOT/$script"
done

# 2. Retry helper wiring across install & update scripts
for script in setup.sh ssh-vpn.sh ins-xray.sh install-api.sh set-br.sh vnstat.sh slowdns.sh update.sh bbr.sh; do
    assert_contains "$script" 'download_with_retry()'
done
assert_contains udp-custom.sh 'udp_attempt in 1 2 3 4 5'
assert_contains ins-xray.sh 'unzip -tq xray.zip'
assert_contains vnstat.sh 'tar -tzf vnstat-2.6.tar.gz'

# 3. Dead 404 bckpbot.sh download removed from setup.sh
if grep -Fq 'download_or_copy "bckpbot.sh"' "$ROOT/setup.sh"; then
    echo 'FAIL: setup.sh still requests nonexistent bckpbot.sh' >&2
    exit 1
fi

# 4. update.sh must never directly overwrite server.js or issue.net with bare wget -O
if grep -Fq 'wget -q -O /etc/nevermore-api/node/server.js' "$ROOT/update.sh" || \
   grep -Fq 'wget -q -O /etc/issue.net' "$ROOT/update.sh"; then
    echo 'FAIL: update.sh still uses unguarded wget -O overwrite' >&2
    exit 1
fi

# 5. Runtime tests for download_with_retry extracted directly from setup.sh
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/state" "$TMP/out"
sed -n '/^download_with_retry() {/,/^}/p' "$ROOT/setup.sh" > "$TMP/helper.sh"
chmod +x "$TMP/helper.sh"

# Mock sleep as instant no-op so test executes immediately
cat > "$TMP/bin/sleep" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/bin/sleep"

# Case A: Both wget and curl fail twice (creating 0-byte temp file like wget -O on TLS reset), then succeed on attempt 3
cat > "$TMP/bin/wget" <<'EOF'
#!/usr/bin/env bash
out=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -O) out="$2"; shift 2 ;;
        *) shift ;;
    esac
done
count_file="${MOCK_STATE}/wget_count"
n=$(cat "$count_file" 2>/dev/null || echo 0)
n=$((n + 1))
echo "$n" > "$count_file"
if [[ "$n" -le 2 ]]; then
    : > "$out"
    exit 4
fi
echo '#!/bin/bash' > "$out"
echo 'echo recovered' >> "$out"
exit 0
EOF
cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
out=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        *) shift ;;
    esac
done
exit 35
EOF
chmod +x "$TMP/bin/wget" "$TMP/bin/curl"

PATH="$TMP/bin:$PATH" MOCK_STATE="$TMP/state" bash -c '
    source "$1"
    download_with_retry "https://example.test/file.sh" "$2" 5 0
' _ "$TMP/helper.sh" "$TMP/out/recovered.sh"

grep -Fq 'echo recovered' "$TMP/out/recovered.sh"
if [[ "$(cat "$TMP/state/wget_count")" -ne 3 ]]; then
    echo "FAIL: expected 3 wget attempts, got $(cat "$TMP/state/wget_count")" >&2
    exit 1
fi

# Case B: wget always fails (exit 4), curl fallback succeeds on attempt 1
rm -f "$TMP/state"/*
cat > "$TMP/bin/wget" <<'EOF'
#!/usr/bin/env bash
out=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -O) out="$2"; shift 2 ;;
        *) shift ;;
    esac
done
: > "$out"
exit 4
EOF
cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
out=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o) out="$2"; shift 2 ;;
        *) shift ;;
    esac
done
echo 'curl-fallback-ok' > "$out"
exit 0
EOF
chmod +x "$TMP/bin/wget" "$TMP/bin/curl"

PATH="$TMP/bin:$PATH" bash -c '
    source "$1"
    download_with_retry "https://example.test/fallback.txt" "$2" 5 0
' _ "$TMP/helper.sh" "$TMP/out/fallback.txt"

grep -Fqx 'curl-fallback-ok' "$TMP/out/fallback.txt"

# Case C: All retries fail -> must fail cleanly AND preserve existing target file without 0-byte truncation
echo 'existing-valid-content' > "$TMP/out/existing.js"
cat > "$TMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 35
EOF
chmod +x "$TMP/bin/curl"

if PATH="$TMP/bin:$PATH" bash -c '
    source "$1"
    download_with_retry "https://example.test/fail.js" "$2" 3 0
' _ "$TMP/helper.sh" "$TMP/out/existing.js"; then
    echo 'FAIL: expected download_with_retry to fail when all attempts fail' >&2
    exit 1
fi

if [[ "$(cat "$TMP/out/existing.js")" != "existing-valid-content" ]]; then
    echo 'FAIL: existing target file was corrupted or truncated on failed download' >&2
    exit 1
fi

if ls "$TMP/out"/existing.js.tmp.* >/dev/null 2>&1; then
    echo 'FAIL: leftover temporary download file was not cleaned up' >&2
    exit 1
fi

# 6. Runtime test for apt_with_retry recovering from dpkg lock / mirror glitch
sed -n '/^apt_with_retry() {/,/^}/p' "$ROOT/setup.sh" > "$TMP/apt_helper.sh"
rm -f "$TMP/state"/*
cat > "$TMP/bin/apt-get" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"update -y"* ]]; then
    exit 0
fi
count_file="${MOCK_STATE}/apt_count"
n=$(cat "$count_file" 2>/dev/null || echo 0)
n=$((n + 1))
echo "$n" > "$count_file"
if [[ "$n" -eq 1 ]]; then
    echo 'E: Could not get lock /var/lib/dpkg/lock-frontend' >&2
    exit 100
fi
exit 0
EOF
cat > "$TMP/bin/dpkg" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/bin/apt-get" "$TMP/bin/dpkg"

PATH="$TMP/bin:$PATH" MOCK_STATE="$TMP/state" bash -c '
    source "$1"
    apt_with_retry install -y dropbear fail2ban
' _ "$TMP/apt_helper.sh"

if [[ "$(cat "$TMP/state/apt_count")" -ne 2 ]]; then
    echo "FAIL: expected apt_with_retry to retry once and succeed on attempt 2" >&2
    exit 1
fi

echo 'PASS: download_with_retry and apt_with_retry handle TLS resets, dpkg locks, and atomic preservation'
