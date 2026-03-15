#!/bin/bash
# API Module: Xray Status
# Args: protocol user

protocol="$1"
user="$2"

if [[ -z "$protocol" || -z "$user" ]]; then
  echo '{"status": "error", "message": "Missing required arguments"}'
  exit 1
fi

xray_bin="$(command -v xray)"
if [[ -z "$xray_bin" ]]; then
  xray_bin="/usr/local/bin/xray"
fi

limit_dir="/etc/xray/limit"
limit_file="${limit_dir}/${protocol}"
lock_file="${limit_dir}/lock-${protocol}"
usage_file="${limit_dir}/usage-${protocol}"

get_stat_value() {
  local name="$1"
  local value
  value="$("$xray_bin" api stats --server=127.0.0.1:10085 --name "$name" 2>/dev/null | awk -F': ' '/"value"/{print $2; exit}' | tr -d '"')"
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

format_bytes() {
  local bytes="$1"
  awk -v b="$bytes" 'BEGIN {
    if (b < 1024) {
      printf "%.2fB", b
    } else if (b < 1024*1024) {
      printf "%.2fKB", b/1024
    } else if (b < 1024*1024*1024) {
      printf "%.2fMB", b/1024/1024
    } else {
      printf "%.2fGB", b/1024/1024/1024
    }
  }'
}

# Find user in either limit_file or lock_file to get their uuid, exp, and limit
user_data=""
if [[ -f "$limit_file" ]]; then
    user_data=$(grep -w "^$user" "$limit_file" | head -n 1)
fi

status_account="UNLOCKED"

if [[ -z "$user_data" && -f "$lock_file" ]]; then
    user_data=$(grep -w "^$user" "$lock_file" | head -n 1)
    if [[ -n "$user_data" ]]; then
        status_account="LOCKED"
    fi
fi

if [[ -z "$user_data" ]]; then
    # User not found in either file, but might exist in xray config.
    # To keep it robust, we just return error if not tracked by limit system.
    echo '{"status": "error", "message": "User not found or not tracked by limit system"}'
    exit 1
fi

read -r u uuid exp limit_gb reset_bytes <<< "$user_data"

if [[ -z "$reset_bytes" || ! "$reset_bytes" =~ ^[0-9]+$ ]]; then
    reset_bytes=0
fi

# Calculate live usage
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

used_formatted="$(format_bytes "$used_bytes")"
total_quota_gb="${limit_gb}GB"

# JSON Response
cat <<EOF
{
  "status": "success",
  "data": {
    "protocol": "$protocol",
    "username": "$user",
    "status_account": "$status_account",
    "quota_limit_gb": "$limit_gb",
    "quota_used_bytes": "$used_bytes",
    "quota_used_formatted": "$used_formatted",
    "expired": "$exp"
  }
}
EOF
