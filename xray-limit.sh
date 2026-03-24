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
touch "$limit_dir/usage-vmess" "$limit_dir/usage-vless" "$limit_dir/usage-trojan"
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

get_usage_record() {
  local usage_file="$1"
  local user="$2"
  local record
  record="$(awk -v u="$user" '$1==u{print $2, $3}' "$usage_file")"
  if [[ -z "$record" ]]; then
    echo "0 0"
    return
  fi
  echo "$record"
}

update_usage_record() {
  local usage_file="$1"
  local user="$2"
  local offset="$3"
  local last_seen="$4"
  sed -i "/^${user} /d" "$usage_file"
  echo "$user $offset $last_seen" >> "$usage_file"
}

remove_user_config() {
  local proto="$1"
  local user="$2"
  case "$proto" in
    vmess)
      sed -i "/^[[:space:]]*#vms $user /,/^[[:space:]]*},{/d" /etc/xray/config.json
      sed -i "/^[[:space:]]*#vmsg $user /,/^[[:space:]]*},{/d" /etc/xray/config.json
      sed -i "/^[[:space:]]*### $user /,/^[[:space:]]*},{/d" /etc/xray/config.json
      ;;
    vless)
      sed -i "/^[[:space:]]*#vls $user /,/^[[:space:]]*},{/d" /etc/xray/config.json
      sed -i "/^[[:space:]]*#vlsg $user /,/^[[:space:]]*},{/d" /etc/xray/config.json
      ;;
    trojan)
      sed -i "/^[[:space:]]*#tr $user /,/^[[:space:]]*},{/d" /etc/xray/config.json
      sed -i "/^[[:space:]]*#trg $user /,/^[[:space:]]*},{/d" /etc/xray/config.json
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
  local usage_file="${limit_dir}/usage-${proto}"

  remove_user_config "$proto" "$user"
  # User is kept in the limit_file so their usage is still visible in the bandwidth menu
  sed -i "/^${user} /d" "$lock_file"
  # User usage is also kept so the bandwidth menu shows their last usage
  # sed -i "/^${user} /d" "$usage_file"
  echo "$user $uuid $exp $limit_gb $reset_bytes" >> "$lock_file"
  echo "$(date '+%Y-%m-%d %H:%M:%S') ${proto} ${user} locked (limit ${limit_gb} GB)" >> "$limit_log"
  systemctl restart xray >/dev/null 2>&1
}

process_limits() {
  local proto="$1"
  local limit_file="${limit_dir}/${proto}"
  local lock_file="${limit_dir}/lock-${proto}"
  local usage_file="${limit_dir}/usage-${proto}"

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
    read -r offset last_seen <<< "$(get_usage_record "$usage_file" "$user")"
    if [[ "$usage" -lt "$last_seen" ]]; then
      offset=$((offset + last_seen))
    fi
    update_usage_record "$usage_file" "$user" "$offset" "$usage"
    total_bytes=$((offset + usage))
    used_bytes=$((total_bytes - reset_bytes))
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
