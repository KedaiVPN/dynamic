#!/usr/bin/env bash
# Safe reader for the active WebSocket paths managed by custom-path.
# This file never evaluates /etc/xray/custom-paths.conf.

XRAY_PATH_CONFIG="${XRAY_PATH_CONFIG:-/etc/xray/custom-paths.conf}"

_xray_path_is_safe() {
    [[ "$1" =~ ^/[A-Za-z0-9._-]+$ ]]
}

_xray_path_value() {
    local key="$1" fallback="$2" value
    value=$(awk -F'"' -v key="$key" '$1 == key "=" { print $2; exit }' "$XRAY_PATH_CONFIG" 2>/dev/null || true)

    if _xray_path_is_safe "$value"; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "$fallback"
    fi
}

VMESS_WS_PATH=$(_xray_path_value VMESS_WS_PATH /vmess)
VLESS_WS_PATH=$(_xray_path_value VLESS_WS_PATH /vless)
TROJAN_WS_PATH=$(_xray_path_value TROJAN_WS_PATH /trojan-ws)
# Validation permits only slash, letters, digits, dot, underscore and dash.
# Encoding the leading slash keeps Trojan URI query values standards-compliant.
TROJAN_WS_PATH_ENCODED=${TROJAN_WS_PATH//\//%2F}
export VMESS_WS_PATH VLESS_WS_PATH TROJAN_WS_PATH TROJAN_WS_PATH_ENCODED
