#!/usr/bin/env bash
set -euo pipefail

PATH_CONFIG="${PATH_CONFIG:-/etc/xray/custom-paths.conf}"
ALIAS_CONFIG="${ALIAS_CONFIG:-/etc/xray/custom-path-aliases.conf}"
NGINX_INCLUDE="${NGINX_INCLUDE:-/etc/nginx/conf.d/xray-custom-paths.inc}"
NGINX_BIN="${NGINX_BIN:-nginx}"
NGINX_RELOAD_CMD="${NGINX_RELOAD_CMD:-systemctl reload nginx}"

readonly DEFAULT_VMESS_PATH="/vmess"
readonly DEFAULT_VLESS_PATH="/vless"
readonly DEFAULT_TROJAN_PATH="/trojan-ws"

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    return 1
}

protocol_defaults() {
    case "$1" in
        vmess) printf '%s|%s|%s\n' "$DEFAULT_VMESS_PATH" "/vmess" "10002" ;;
        vless) printf '%s|%s|%s\n' "$DEFAULT_VLESS_PATH" "/vless" "10001" ;;
        trojan) printf '%s|%s|%s\n' "$DEFAULT_TROJAN_PATH" "/trojan-ws" "10003" ;;
        *) fail "Unknown protocol: $1" ;;
    esac
}

validate_path() {
    local candidate="$1"
    [[ "$candidate" =~ ^/[A-Za-z0-9._-]+$ ]] || return 1

    case "$candidate" in
        /|/api|/api/monitoring/stream|/vmess|/vless|/trojan-ws|/ss-ws|/vmess-grpc|/vless-grpc|/trojan-grpc|/ss-grpc)
            return 1
            ;;
    esac
}

ensure_files() {
    mkdir -p "$(dirname "$PATH_CONFIG")" "$(dirname "$ALIAS_CONFIG")" "$(dirname "$NGINX_INCLUDE")"

    if [[ ! -f "$PATH_CONFIG" ]]; then
        cat >"$PATH_CONFIG" <<EOF
# Managed by /usr/bin/custom-path. Active paths are used for new WS accounts.
VMESS_WS_PATH="$DEFAULT_VMESS_PATH"
VLESS_WS_PATH="$DEFAULT_VLESS_PATH"
TROJAN_WS_PATH="$DEFAULT_TROJAN_PATH"
EOF
        chmod 600 "$PATH_CONFIG"
    fi

    [[ -f "$ALIAS_CONFIG" ]] || : >"$ALIAS_CONFIG"
    chmod 600 "$ALIAS_CONFIG"
    [[ -f "$NGINX_INCLUDE" ]] || : >"$NGINX_INCLUDE"
}

active_path() {
    local key="$1" fallback="$2" value
    value=$(awk -F'"' -v key="$key" '$1 == key "=" { print $2; exit }' "$PATH_CONFIG" 2>/dev/null || true)
    if validate_path "$value"; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "$fallback"
    fi
}

path_is_registered_by_other_protocol() {
    local requested_protocol="$1" candidate="$2" owner
    owner=$(awk -F'|' -v path="$candidate" '$2 == path { print $1; exit }' "$ALIAS_CONFIG")
    [[ -n "$owner" && "$owner" != "$requested_protocol" ]]
}

register_alias() {
    local protocol="$1" public_path="$2" defaults internal port
    defaults=$(protocol_defaults "$protocol")
    IFS='|' read -r _ internal port <<<"$defaults"

    if path_is_registered_by_other_protocol "$protocol" "$public_path"; then
        fail "Path $public_path is already owned by another protocol"
        return
    fi

    if ! awk -F'|' -v proto="$protocol" -v path="$public_path" '$1 == proto && $2 == path { found=1 } END { exit !found }' "$ALIAS_CONFIG"; then
        printf '%s|%s|%s|%s\n' "$protocol" "$public_path" "$internal" "$port" >>"$ALIAS_CONFIG"
    fi
}

write_active_path() {
    local protocol="$1" public_path="$2" key tmp
    case "$protocol" in
        vmess) key="VMESS_WS_PATH" ;;
        vless) key="VLESS_WS_PATH" ;;
        trojan) key="TROJAN_WS_PATH" ;;
        *) fail "Unknown protocol: $protocol"; return ;;
    esac

    tmp=$(mktemp "${PATH_CONFIG}.XXXXXX")
    awk -v key="$key" -v value="$public_path" '
        BEGIN { replaced=0 }
        $0 ~ "^" key "=" { print key "=\"" value "\""; replaced=1; next }
        { print }
        END { if (!replaced) print key "=\"" value "\"" }
    ' "$PATH_CONFIG" >"$tmp"
    chmod 600 "$tmp"
    mv "$tmp" "$PATH_CONFIG"
}

render_nginx_include() {
    local tmp protocol public_path internal port escaped
    tmp=$(mktemp "${NGINX_INCLUDE}.XXXXXX")
    {
        printf '# Managed by /usr/bin/custom-path. Do not edit manually.\n'
        while IFS='|' read -r protocol public_path internal port; do
            [[ -n "$protocol" ]] || continue
            [[ "$protocol" =~ ^(vmess|vless|trojan)$ ]] || { rm -f "$tmp"; fail "Invalid protocol in alias registry"; return; }
            validate_path "$public_path" || { rm -f "$tmp"; fail "Invalid path in alias registry"; return; }
            case "$protocol:$internal:$port" in
                vmess:/vmess:10002|vless:/vless:10001|trojan:/trojan-ws:10003) ;;
                *) rm -f "$tmp"; fail "Invalid backend mapping in alias registry"; return ;;
            esac
            escaped=${public_path//./\\.}
            cat <<EOF

location ~ ^${escaped}\$ {
    rewrite ^ ${internal} break;

    proxy_redirect off;
    proxy_pass http://127.0.0.1:${port};
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
}
EOF
        done <"$ALIAS_CONFIG"
    } >"$tmp"
    chmod 644 "$tmp"
    printf '%s\n' "$tmp"
}

apply_nginx_include() {
    local candidate backup had_previous=0
    candidate=$(render_nginx_include) || return
    backup=$(mktemp "${NGINX_INCLUDE}.backup.XXXXXX")
    if [[ -f "$NGINX_INCLUDE" ]]; then
        cp "$NGINX_INCLUDE" "$backup"
        had_previous=1
    fi

    mv "$candidate" "$NGINX_INCLUDE"
    if ! "$NGINX_BIN" -t; then
        if [[ "$had_previous" -eq 1 ]]; then mv "$backup" "$NGINX_INCLUDE"; else : >"$NGINX_INCLUDE"; fi
        fail "Nginx syntax check failed; previous include was restored"
        return
    fi

    if ! bash -c "$NGINX_RELOAD_CMD"; then
        mv "$backup" "$NGINX_INCLUDE"
        fail "Nginx reload failed; previous include was restored"
        return
    fi
    rm -f "$backup"
}

set_path() {
    local protocol="$1" public_path="$2" path_backup alias_backup
    protocol_defaults "$protocol" >/dev/null || return
    validate_path "$public_path" || { fail "Path must match ^/[A-Za-z0-9._-]+$ and cannot use a reserved route"; return; }

    ensure_files
    path_backup=$(mktemp "${PATH_CONFIG}.backup.XXXXXX")
    alias_backup=$(mktemp "${ALIAS_CONFIG}.backup.XXXXXX")
    cp "$PATH_CONFIG" "$path_backup"
    cp "$ALIAS_CONFIG" "$alias_backup"

    if ! register_alias "$protocol" "$public_path" || ! write_active_path "$protocol" "$public_path" || ! apply_nginx_include; then
        mv "$path_backup" "$PATH_CONFIG"
        mv "$alias_backup" "$ALIAS_CONFIG"
        fail "Custom path was not saved because Nginx validation or reload failed"
        return
    fi

    rm -f "$path_backup" "$alias_backup"
    printf 'Active %s WebSocket path: %s\n' "$protocol" "$public_path"
}

show_paths() {
    ensure_files
    printf 'VMESS active path : %s\n' "$(active_path VMESS_WS_PATH "$DEFAULT_VMESS_PATH")"
    printf 'VLESS active path : %s\n' "$(active_path VLESS_WS_PATH "$DEFAULT_VLESS_PATH")"
    printf 'TROJAN active path: %s\n' "$(active_path TROJAN_WS_PATH "$DEFAULT_TROJAN_PATH")"
}

list_aliases() {
    ensure_files
    if [[ -s "$ALIAS_CONFIG" ]]; then
        column -t -s '|' "$ALIAS_CONFIG" 2>/dev/null || cat "$ALIAS_CONFIG"
    else
        echo 'No custom aliases configured.'
    fi
}

interactive_menu() {
    local choice protocol path
    while true; do
        clear 2>/dev/null || true
        echo '================ CUSTOM PATH ================'
        show_paths
        echo '---------------------------------------------'
        echo '[1] Set active VMESS path'
        echo '[2] Set active VLESS path'
        echo '[3] Set active TROJAN path'
        echo '[4] List custom aliases'
        echo '[x] Back'
        read -r -p 'Select menu: ' choice
        case "$choice" in
            1) protocol=vmess ;;
            2) protocol=vless ;;
            3) protocol=trojan ;;
            4) list_aliases; read -r -p 'Press Enter to continue...'; continue ;;
            x|X) return ;;
            *) echo 'Invalid menu.'; sleep 1; continue ;;
        esac
        read -r -p "New ${protocol} path (example: /${protocol}-lea): " path
        set_path "$protocol" "$path" || true
        read -r -p 'Press Enter to continue...'
    done
}

case "${1:-}" in
    --validate-path)
        [[ $# -eq 2 ]] || exit 2
        validate_path "$2"
        ;;
    --set)
        [[ $# -eq 3 ]] || exit 2
        set_path "$2" "$3"
        ;;
    --show)
        show_paths
        ;;
    --list)
        list_aliases
        ;;
    '')
        interactive_menu
        ;;
    *)
        echo "Usage: $0 [--validate-path PATH | --set vmess|vless|trojan PATH | --show | --list]" >&2
        exit 2
        ;;
esac
