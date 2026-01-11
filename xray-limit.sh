#!/bin/bash

xray_bin="$(command -v xray)"
if [[ -z "$xray_bin" ]]; then
  xray_bin="/usr/local/bin/xray"
fi
if [[ ! -x "$xray_bin" ]]; then
  exit 0
fi

limit_dir="/etc/xray/limit"
limit_log="/root/log-limit.txt"

mkdir -p "$limit_dir"
touch "$limit_dir/vmess" "$limit_dir/vless" "$limit_dir/trojan"
touch "$limit_dir/lock-vmess" "$limit_dir/lock-vless" "$limit_dir/lock-trojan"
touch "$limit_log"

get_stat_value() {
  local name="$1"
  local value
  value="$("$xray_bin" api stats --server=127.0.0.1:10085 --name "$name" 2>/dev/null | awk -F': ' '/"value"/{print $2; exit}')"
  if [[ -z "$value" ]]; then
    echo 0
    return
  fi
  echo "$value"
}

get_usage_bytes() {
  local user="$1"
  local up down
  up="$(get_stat_value "user>>>${user}>>>traffic>>>uplink")"
  down="$(get_stat_value "user>>>${user}>>>traffic>>>downlink")"
  echo $((up + down))
}

remove_user_config() {
  local proto="$1"
  local user="$2"
  case "$proto" in
    vmess)
      sed -i "/^#vms $user /,/^},{/d" /etc/xray/config.json
      sed -i "/^#vmsg $user /,/^},{/d" /etc/xray/config.json
      sed -i "/^### $user /,/^},{/d" /etc/xray/config.json
      ;;
    vless)
      sed -i "/^#vls $user /,/^},{/d" /etc/xray/config.json
      sed -i "/^#vlsg $user /,/^},{/d" /etc/xray/config.json
      ;;
    trojan)
      sed -i "/^#tr $user /,/^},{/d" /etc/xray/config.json
      sed -i "/^#trg $user /,/^},{/d" /etc/xray/config.json
      ;;
  esac
}

lock_user() {
  local proto="$1"
  local user="$2"
  local uuid="$3"
  local exp="$4"
  local limit_gb="$5"
  local reset_bytes="$6"
  local limit_file="${limit_dir}/${proto}"
  local lock_file="${limit_dir}/lock-${proto}"

  remove_user_config "$proto" "$user"
  sed -i "/^${user} /d" "$limit_file"
  sed -i "/^${user} /d" "$lock_file"
  echo "$user $uuid $exp $limit_gb $reset_bytes" >> "$lock_file"
  echo "$(date '+%Y-%m-%d %H:%M:%S') ${proto} ${user} locked (limit ${limit_gb} GB)" >> "$limit_log"
  systemctl restart xray >/dev/null 2>&1
}

process_limits() {
  local proto="$1"
  local limit_file="${limit_dir}/${proto}"
  local lock_file="${limit_dir}/lock-${proto}"

  while read -r user uuid exp limit_gb reset_bytes; do
    if [[ -z "$user" || -z "$limit_gb" ]]; then
      continue
    fi
    if ! [[ "$limit_gb" =~ ^[0-9]+$ ]]; then
      continue
    fi
    if [[ -z "$reset_bytes" ]]; then
      reset_bytes=0
    fi
    if ! [[ "$reset_bytes" =~ ^[0-9]+$ ]]; then
      reset_bytes=0
    fi
    usage="$(get_usage_bytes "$user")"
    used_bytes=$((usage - reset_bytes))
    if [[ "$used_bytes" -lt 0 ]]; then
      used_bytes=0
    fi
    limit_bytes=$((limit_gb * 1024 * 1024 * 1024))
    if [[ "$limit_bytes" -gt 0 && "$used_bytes" -ge "$limit_bytes" ]]; then
      lock_user "$proto" "$user" "$uuid" "$exp" "$limit_gb" "$reset_bytes"
    fi
  done < "$limit_file"
}

process_limits "vmess"
process_limits "vless"
process_limits "trojan"
