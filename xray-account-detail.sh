#!/usr/bin/env bash
# Shared read-only lookup for Xray account detail menus.
# config.json remains the source of truth for active accounts; lock-<protocol>
# remains the source of truth after a bandwidth lock removes an account from it.

xray_account_detail_lookup() {
    local protocol="$1" user="$2"
    local config_file="${3:-/etc/xray/config.json}"
    local limit_dir="${4:-/etc/xray/limit}"
    local marker limit_file lock_file record marker_line json_line

    [[ "$protocol" =~ ^(vmess|vless|trojan)$ ]] || return 2
    [[ "$user" =~ ^[A-Za-z0-9_-]+$ ]] || return 2

    case "$protocol" in
        vmess) marker="#vms" ;;
        vless) marker="#vls" ;;
        trojan) marker="#tr" ;;
    esac

    limit_file="${limit_dir}/${protocol}"
    lock_file="${limit_dir}/lock-${protocol}"

    DETAIL_UUID=""
    DETAIL_EXP=""
    DETAIL_QUOTA="N/A"
    DETAIL_IP_LIMIT="N/A"
    DETAIL_STATE="active"

    # A locked Xray account is intentionally absent from config.json. Read its
    # durable limit record first and return it as locked without treating it as
    # a missing account.
    record=$(awk -v u="$user" '$1 == u { print $0; exit }' "$lock_file" 2>/dev/null || true)
    if [[ -n "$record" ]]; then
        read -r _ DETAIL_UUID DETAIL_EXP DETAIL_QUOTA DETAIL_IP_LIMIT _ <<< "$record"
        DETAIL_STATE="locked"
        return 0
    fi

    marker_line=$(awk -v marker="$marker" -v u="$user" '$1 == marker && $2 == u { print; exit }' "$config_file" 2>/dev/null || true)
    [[ -n "$marker_line" ]] || return 1

    DETAIL_EXP=$(awk '{ print $3 }' <<< "$marker_line")
    json_line=$(awk -v marker="$marker" -v u="$user" '
        $1 == marker && $2 == u { want=1; next }
        want && /"(id|password)"/ { print; exit }
    ' "$config_file" 2>/dev/null || true)
    DETAIL_UUID=$(sed -nE 's/.*"(id|password)"[[:space:]]*:[[:space:]]*"([^"]+)".*/\2/p' <<< "$json_line")
    [[ -n "$DETAIL_UUID" ]] || return 1

    record=$(awk -v u="$user" '$1 == u { print $0; exit }' "$limit_file" 2>/dev/null || true)
    if [[ -n "$record" ]]; then
        read -r _ _ DETAIL_EXP DETAIL_QUOTA DETAIL_IP_LIMIT _ <<< "$record"
    fi

    return 0
}
