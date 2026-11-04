#!/usr/bin/env bash
# Shared SlowDNS state reader for terminal and API account output.

SLOWDNS_DIR=${SLOWDNS_DIR:-/etc/slowdns}
SLOWDNS_CONFIG=${SLOWDNS_CONFIG:-${SLOWDNS_DIR}/config}
SLOWDNS_KEY_FILE=${SLOWDNS_KEY_FILE:-${SLOWDNS_DIR}/server.pub}

slowdns_load_config() {
    SLOWDNS_ENABLED=0
    SLOWDNS_DOMAIN=""
    SLOWDNS_NS_DOMAIN=""
    SLOWDNS_PUBKEY=""

    if [[ -r "$SLOWDNS_CONFIG" ]]; then
        # The manager writes this file with validated values only.
        while IFS='=' read -r key value; do
            value=${value%$'\r'}
            case "$key" in
                enabled) [[ "$value" == 1 ]] && SLOWDNS_ENABLED=1 ;;
                domain) SLOWDNS_DOMAIN="$value" ;;
                ns_domain) SLOWDNS_NS_DOMAIN="$value" ;;
            esac
        done < "$SLOWDNS_CONFIG"
    fi

    if [[ -z "$SLOWDNS_DOMAIN" && -r /etc/xray/domain ]]; then
        SLOWDNS_DOMAIN=$(tr -d '[:space:]' < /etc/xray/domain)
    fi
    if [[ -z "$SLOWDNS_NS_DOMAIN" && "$SLOWDNS_DOMAIN" =~ ^[^.]+\..+ ]]; then
        SLOWDNS_NS_DOMAIN="ns-${SLOWDNS_DOMAIN}"
    fi
    if [[ -r "$SLOWDNS_KEY_FILE" ]]; then
        SLOWDNS_PUBKEY=$(tr -d '[:space:]' < "$SLOWDNS_KEY_FILE")
    fi

    if [[ ! "$SLOWDNS_DOMAIN" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$ ]]; then
        SLOWDNS_DOMAIN=""
    fi
    if [[ ! "$SLOWDNS_NS_DOMAIN" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$ ]]; then
        SLOWDNS_NS_DOMAIN=""
    fi
    if [[ ! "$SLOWDNS_PUBKEY" =~ ^[0-9a-fA-F]{64}$ ]]; then
        SLOWDNS_PUBKEY=""
    fi
}

slowdns_is_active() {
    [[ "$SLOWDNS_ENABLED" == 1 && -n "$SLOWDNS_NS_DOMAIN" && -n "$SLOWDNS_PUBKEY" ]] || return 1
    command -v systemctl >/dev/null 2>&1 || return 1
    systemctl is-active --quiet slowdns.service
}

slowdns_account_fields() {
    slowdns_load_config
    if slowdns_is_active; then
        printf 'Ns-Domain : %s\n' "$SLOWDNS_NS_DOMAIN"
        printf 'Pubkey    : %s\n' "$SLOWDNS_PUBKEY"
    fi
}

slowdns_json_fields() {
    slowdns_load_config
    if slowdns_is_active; then
        printf ',\n    "ns_domain": "%s",\n    "pubkey": "%s"' "$SLOWDNS_NS_DOMAIN" "$SLOWDNS_PUBKEY"
    fi
}
