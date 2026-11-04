#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/slowdns"
printf 'enabled=1\ndomain=depa2.alternat.my.id\nns_domain=ns-depa2.alternat.my.id\n' > "$TMP/slowdns/config"
printf '%064d\n' 0 > "$TMP/slowdns/server.pub"

SLOWDNS_DIR="$TMP/slowdns" \
SLOWDNS_CONFIG="$TMP/slowdns/config" \
SLOWDNS_KEY_FILE="$TMP/slowdns/server.pub" \
  bash -c 'source "$0"; slowdns_load_config; [[ "$SLOWDNS_ENABLED" == 1 ]]; [[ "$SLOWDNS_NS_DOMAIN" == ns-depa2.alternat.my.id ]]; [[ ${#SLOWDNS_PUBKEY} -eq 64 ]]; slowdns_is_active(){ return 0; }; out=$(slowdns_json_fields); [[ "$out" == *"ns_domain"* ]]; [[ "$out" == *"pubkey"* ]]' "$ROOT/slowdns-config.sh"

# Disabled state must not expose account metadata.
printf 'enabled=0\ndomain=depa2.alternat.my.id\nns_domain=ns-depa2.alternat.my.id\n' > "$TMP/slowdns/config"
SLOWDNS_DIR="$TMP/slowdns" \
SLOWDNS_CONFIG="$TMP/slowdns/config" \
SLOWDNS_KEY_FILE="$TMP/slowdns/server.pub" \
  bash -c 'source "$0"; slowdns_load_config; slowdns_is_active(){ return 1; }; [[ -z "$(slowdns_json_fields)" ]]' "$ROOT/slowdns-config.sh"

echo 'PASS: SlowDNS config and conditional account metadata'
