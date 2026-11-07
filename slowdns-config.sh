#!/usr/bin/env bash
# Shared read-only SlowDNS state reader for terminal and API account output.
# The manager uses the official HTTP Custom package under /root/slowdns.

SLOWDNS_DIR=${SLOWDNS_DIR:-/root/slowdns}
SLOWDNS_ENV_FILE=${SLOWDNS_ENV_FILE:-${SLOWDNS_DIR}/slowdns.env}
SLOWDNS_KEY_FILE=${SLOWDNS_KEY_FILE:-${SLOWDNS_DIR}/server.pub}
SLOWDNS_RESOLVER=${SLOWDNS_RESOLVER:-1.1.1.1:53}

slowdns_load_config() {
    SLOWDNS_ENABLED=""
    SLOWDNS_DOMAIN=""
    SLOWDNS_NS_DOMAIN=""
    SLOWDNS_PUBKEY=""
    SLOWDNS_UDP_ADDR=""

    if [[ -r "$SLOWDNS_ENV_FILE" ]]; then
        # Read only manager-owned KEY=VALUE fields; never source the env file.
        while IFS='=' read -r key value; do
            value=${value%$'\r'}
            value=${value#\"}; value=${value%\"}
            case "$key" in
                SLOWDNS_ENABLED) [[ "$value" == 1 ]] && SLOWDNS_ENABLED=1; [[ "$value" == 0 ]] && SLOWDNS_ENABLED=0 ;;
                SLOWDNS_DOMAIN) SLOWDNS_DOMAIN="$value" ;;
                SLOWDNS_NS_DOMAIN) SLOWDNS_NS_DOMAIN="$value" ;;
                SLOWDNS_UDP_ADDR) SLOWDNS_UDP_ADDR="$value" ;;
                SLOWDNS_RESOLVER) SLOWDNS_RESOLVER="$value" ;;
            esac
        done < "$SLOWDNS_ENV_FILE"
    fi

    if [[ -z "$SLOWDNS_ENABLED" ]]; then
        if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet slowdns.service 2>/dev/null; then
            SLOWDNS_ENABLED=1
        else
            SLOWDNS_ENABLED=0
        fi
    fi

    local xray_domain=""
    if [[ -r /etc/xray/domain ]]; then
        xray_domain=$(tr -d '[:space:]' < /etc/xray/domain)
    fi

    if [[ -n "$xray_domain" && "$xray_domain" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$ && "$xray_domain" == *.* ]]; then
        SLOWDNS_DOMAIN="$xray_domain"
        SLOWDNS_NS_DOMAIN="ns-${xray_domain}"
    fi

    if [[ -z "$SLOWDNS_NS_DOMAIN" && "$SLOWDNS_DOMAIN" =~ ^[^.]+\..+ ]]; then
        SLOWDNS_NS_DOMAIN="ns-${SLOWDNS_DOMAIN}"
    fi
    if [[ -r "$SLOWDNS_KEY_FILE" ]]; then
        SLOWDNS_PUBKEY=$(tr -d '[:space:]' < "$SLOWDNS_KEY_FILE")
    fi

    # Auto-sync on-disk env and service if running as root and domain changed
    if [[ ${EUID:-$(id -u)} -eq 0 && -f "$SLOWDNS_ENV_FILE" && -f /etc/systemd/system/slowdns.service ]]; then
        local env_ns=""
        env_ns=$(awk -F= '$1=="SLOWDNS_NS_DOMAIN" {gsub(/"/,"",$2); print $2}' "$SLOWDNS_ENV_FILE" 2>/dev/null || true)
        if [[ -n "$SLOWDNS_NS_DOMAIN" && "$env_ns" != "$SLOWDNS_NS_DOMAIN" ]]; then
            sed -i "s|^SLOWDNS_DOMAIN=.*|SLOWDNS_DOMAIN=\"${SLOWDNS_DOMAIN}\"|" "$SLOWDNS_ENV_FILE" 2>/dev/null || true
            sed -i "s|^SLOWDNS_NS_DOMAIN=.*|SLOWDNS_NS_DOMAIN=\"${SLOWDNS_NS_DOMAIN}\"|" "$SLOWDNS_ENV_FILE" 2>/dev/null || true
            if ! grep -q "SLOWDNS_NS_DOMAIN=" "$SLOWDNS_ENV_FILE"; then
                echo "SLOWDNS_NS_DOMAIN=\"${SLOWDNS_NS_DOMAIN}\"" >> "$SLOWDNS_ENV_FILE"
            fi
            sed -i -E "s|(server\.key[[:space:]]+)[^[:space:]]+|\1${SLOWDNS_NS_DOMAIN}|" /etc/systemd/system/slowdns.service 2>/dev/null || true
            if command -v systemctl >/dev/null 2>&1; then
                systemctl daemon-reload >/dev/null 2>&1 || true
                if systemctl is-active --quiet slowdns.service 2>/dev/null; then
                    systemctl restart slowdns.service >/dev/null 2>&1 || true
                fi
            fi
        fi
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
    # HTTP Custom must query the actual SlowDNS listener, not a recursive
    # resolver or a hostname whose DNS delegation may still be cached.
    if [[ "$SLOWDNS_UDP_ADDR" =~ ^[0-9]+(\.[0-9]+){3}:53$ ]]; then
        SLOWDNS_RESOLVER="$SLOWDNS_UDP_ADDR"
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
        printf 'DNS       : %s\n' "$SLOWDNS_RESOLVER"
        printf 'Domain    : %s\n' "$SLOWDNS_DOMAIN"
        printf 'Ns-Domain : %s\n' "$SLOWDNS_NS_DOMAIN"
        printf 'Pubkey    : %s\n' "$SLOWDNS_PUBKEY"
    fi
}

slowdns_json_fields() {
    slowdns_load_config
    if slowdns_is_active; then
        printf ',\n    "dns": "%s",\n    "domain": "%s",\n    "ns_domain": "%s",\n    "pubkey": "%s"' \
            "$SLOWDNS_RESOLVER" "$SLOWDNS_DOMAIN" "$SLOWDNS_NS_DOMAIN" "$SLOWDNS_PUBKEY"
    fi
}
