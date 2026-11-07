#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/slowdns" "$TMP/etc/xray"
printf 'SLOWDNS_ENABLED="1"\nSLOWDNS_DOMAIN="old.example.com"\nSLOWDNS_NS_DOMAIN="ns-old.example.com"\nSLOWDNS_UDP_ADDR="103.150.60.5:53"\nSLOWDNS_RESOLVER="1.1.1.1:53"\n' > "$TMP/slowdns/slowdns.env"
printf '%064d\n' 0 > "$TMP/slowdns/server.pub"
echo "new.example.com" > "$TMP/domain"

cp "$ROOT/slowdns-config.sh" "$TMP/slowdns-config.sh"
sed -i "s|/etc/xray/domain|$TMP/domain|g" "$TMP/slowdns-config.sh"

SLOWDNS_DIR="$TMP/slowdns" \
SLOWDNS_ENV_FILE="$TMP/slowdns/slowdns.env" \
SLOWDNS_KEY_FILE="$TMP/slowdns/server.pub" \
  bash -c '
    set -e
    source "$0"
    slowdns_load_config
    [[ "$SLOWDNS_DOMAIN" == "new.example.com" ]]
    [[ "$SLOWDNS_NS_DOMAIN" == "ns-new.example.com" ]]
    slowdns_is_active() { return 0; }
    out=$(slowdns_account_fields)
    [[ "$out" == *"Domain    : new.example.com"* ]]
    [[ "$out" == *"Ns-Domain : ns-new.example.com"* ]]
  ' "$TMP/slowdns-config.sh"

echo "PASS: SlowDNS dynamic domain synchronization"
