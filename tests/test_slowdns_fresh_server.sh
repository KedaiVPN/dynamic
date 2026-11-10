#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/legacy"

cat > "$TMP/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  is-active) exit 0 ;;
  daemon-reload|enable|restart|disable) exit 0 ;;
  *) exit 0 ;;
esac
EOF
cat > "$TMP/bin/wget" <<'EOF'
#!/usr/bin/env bash
out=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    -O) out=$2; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "$out" ]]
cat > "$out" <<'BIN'
#!/usr/bin/env bash
if [[ "${1:-}" == -gen-key ]]; then
  shift
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -privkey-file) key=$2; shift 2 ;;
      -pubkey-file) pub=$2; shift 2 ;;
      *) shift ;;
    esac
  done
  printf '%064d\n' 1 > "$key"
  printf '%064d\n' 2 > "$pub"
fi
BIN
chmod 755 "$out"
EOF

cat > "$TMP/bin/sha256sum" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == */slowdns.* ]]; then
  printf '%s  %s\n' 'a9d19e39ae23261628e8f21dac79548b31dceb45f959017bc50300e7ebfcad7d' "$1"
else
  /usr/bin/sha256sum "$@"
fi
EOF

cat > "$TMP/bin/ip" <<'EOF'
#!/usr/bin/env bash
if [[ "${1:-}" == -4 && "${2:-}" == route ]]; then
  echo '1.1.1.1 via 198.51.100.1 dev ens18 src 198.51.100.7 uid 0'
fi
EOF
cat > "$TMP/bin/iptables" <<'EOF'
#!/usr/bin/env bash
# No existing rules in this fresh-server fixture: checks report absent, while
# inserts/deletes succeed so the manager can exercise its idempotent path.
for arg in "$@"; do
  [[ "$arg" == -C ]] && exit 1
done
exit 0
EOF
cat > "$TMP/bin/iptables-save" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$TMP/bin/ss" <<'EOF'
#!/usr/bin/env bash
echo 'UNCONN 0 0 198.51.100.7:53 0.0.0.0:*'
EOF
chmod 755 "$TMP/bin"/*

PATH="$TMP/bin:$PATH" \
SLOWDNS_DIR="$TMP/slowdns" \
SLOWDNS_ENV_FILE="$TMP/slowdns/slowdns.env" \
SLOWDNS_BIN="$TMP/slowdns/slowdns" \
SLOWDNS_KEY="$TMP/slowdns/server.key" \
SLOWDNS_PUB="$TMP/slowdns/server.pub" \
SLOWDNS_SERVICE="$TMP/slowdns.service" \
SLOWDNS_WATCHDOG_BIN="$TMP/slowdns-watchdog.sh" \
SLOWDNS_WATCHDOG_SERVICE="$TMP/slowdns-watchdog.service" \
SLOWDNS_WATCHDOG_TIMER="$TMP/slowdns-watchdog.timer" \
SLOWDNS_BINARY_URL='https://example.invalid/slowdns-linux-amd64' \
SLOWDNS_LEGACY_DIR="$TMP/legacy" \
SLOWDNS_DOMAIN_OVERRIDE='fresh.example.test' \
SLOWDNS_BIND_IP='198.51.100.7' \
SLOWDNS_RESOLVER='1.1.1.1:53' \
bash "$ROOT/slowdns.sh" enable

[[ -x "$TMP/slowdns/slowdns" ]]
[[ -s "$TMP/slowdns/server.key" ]]
[[ -s "$TMP/slowdns/server.pub" ]]
[[ "$(wc -c < "$TMP/slowdns/server.key")" -eq 65 ]]
[[ "$(wc -c < "$TMP/slowdns/server.pub")" -eq 65 ]]
grep -Fqx 'SLOWDNS_DOMAIN="fresh.example.test"' "$TMP/slowdns/slowdns.env"
grep -Fqx 'SLOWDNS_NS_DOMAIN="ns-fresh.example.test"' "$TMP/slowdns/slowdns.env"
grep -Fqx 'SLOWDNS_UDP_ADDR="198.51.100.7:53"' "$TMP/slowdns/slowdns.env"
grep -Fq -- '-udp 198.51.100.7:53' "$TMP/slowdns.service"
grep -Fq -- 'ns-fresh.example.test 127.0.0.1:22' "$TMP/slowdns.service"
[[ -x "$TMP/slowdns-watchdog.sh" ]]
[[ -s "$TMP/slowdns-watchdog.service" ]]
[[ -s "$TMP/slowdns-watchdog.timer" ]]
grep -Fqx "ExecStart=$TMP/slowdns-watchdog.sh" "$TMP/slowdns-watchdog.service"
grep -Fqx 'Unit=slowdns-watchdog.service' "$TMP/slowdns-watchdog.timer"
[[ ! -e "$TMP/legacy/server.key" ]]
[[ ! -e "$TMP/legacy/server.pub" ]]

echo 'PASS: fresh server installs official SlowDNS without legacy state'
