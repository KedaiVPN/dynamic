#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/slowdns"
printf 'SLOWDNS_ENABLED="1"\nSLOWDNS_DOMAIN="depa2.alternat.my.id"\nSLOWDNS_NS_DOMAIN="ns-depa2.alternat.my.id"\nSLOWDNS_UDP_ADDR="103.150.60.5:53"\nSLOWDNS_RESOLVER="1.1.1.1:53"\n' > "$TMP/slowdns/slowdns.env"
printf '%064d\n' 0 > "$TMP/slowdns/server.pub"

SLOWDNS_DIR="$TMP/slowdns" \
SLOWDNS_ENV_FILE="$TMP/slowdns/slowdns.env" \
SLOWDNS_KEY_FILE="$TMP/slowdns/server.pub" \
  bash -c 'set -e; source "$0"; slowdns_load_config; [[ "$SLOWDNS_ENABLED" == 1 ]]; [[ "$SLOWDNS_DOMAIN" == depa2.alternat.my.id ]]; [[ "$SLOWDNS_NS_DOMAIN" == ns-depa2.alternat.my.id ]]; [[ "$SLOWDNS_UDP_ADDR" == 103.150.60.5:53 ]]; [[ "$SLOWDNS_RESOLVER" == 103.150.60.5:53 ]]; [[ ${#SLOWDNS_PUBKEY} -eq 64 ]]; slowdns_is_active(){ return 0; }; out=$(slowdns_account_fields); [[ "$out" == *"DNS       : 103.150.60.5:53"* ]]; [[ "$out" == *"Domain    : depa2.alternat.my.id"* ]]; [[ "$out" == *"Ns-Domain : ns-depa2.alternat.my.id"* ]]; out=$(slowdns_json_fields); [[ "$out" == *"\"dns\": \"103.150.60.5:53\""* ]]; [[ "$out" == *"domain"* ]]; [[ "$out" == *"ns_domain"* ]]; [[ "$out" == *"pubkey"* ]]' "$ROOT/slowdns-config.sh"

# Disabled state must not expose account metadata.
printf 'SLOWDNS_ENABLED="0"\nSLOWDNS_DOMAIN="depa2.alternat.my.id"\nSLOWDNS_NS_DOMAIN="ns-depa2.alternat.my.id"\n' > "$TMP/slowdns/slowdns.env"
SLOWDNS_DIR="$TMP/slowdns" \
SLOWDNS_ENV_FILE="$TMP/slowdns/slowdns.env" \
SLOWDNS_KEY_FILE="$TMP/slowdns/server.pub" \
  bash -c 'set -e; source "$0"; slowdns_load_config; slowdns_is_active(){ return 1; }; [[ -z "$(slowdns_json_fields)" ]]' "$ROOT/slowdns-config.sh"

echo 'PASS: SlowDNS config and conditional account metadata'
