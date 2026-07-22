#!/bin/bash
# API Module: SSH Renew
# Args: user add_days quota iplimit

user="$1"
add_days=$(echo "$2" | tr -d '\r\n')
quota="$3"
iplimit="$4"

if [[ -z "$user" || -z "$add_days" ]]; then
  echo '{"status": "error", "message": "Missing required arguments"}'
  exit 1
fi

if ! id "$user" >/dev/null 2>&1; then
  echo '{"status": "error", "message": "User does not exist"}'
  exit 1
fi

# Calculate base time
current_exp_str=$(chage -l "$user" | grep "Account expires" | cut -d: -f2)
if [[ "$current_exp_str" == *"never"* ]]; then
    current_exp_sec=$(date +%s)
else
    current_exp_sec=$(date -d "$current_exp_str" +%s 2>/dev/null)
    if [[ -z "$current_exp_sec" ]]; then
        current_exp_sec=$(date +%s)
    fi
fi

now=$(date +%s)
# Logic: If expired, renew from NOW. If active, renew from current expiry.
if [[ $current_exp_sec -lt $now ]]; then
    base_sec=$now
else
    base_sec=$current_exp_sec
fi

# Parse add_days (supports days, date string, and unix timestamp)
if [[ "$add_days" =~ ^[0-9]+$ ]]; then
  if [ ${#add_days} -ge 10 ]; then
    # Unix timestamp (absolute target)
    if [ ${#add_days} -eq 13 ]; then
      new_exp_sec=$((add_days / 1000))
    else
      new_exp_sec=$add_days
    fi
  else
    # Number of days to add
    add_sec=$((add_days * 86400))
    new_exp_sec=$((base_sec + add_sec))
  fi
else
  # Date string (absolute target)
  parsed_ts=$(date -d "$add_days" +%s 2>/dev/null)
  if [ -n "$parsed_ts" ]; then
    new_exp_sec=$parsed_ts
  else
    echo '{"status": "error", "message": "Invalid renewal date format"}'
    exit 1
  fi
fi

new_exp_date=$(date -d "@$new_exp_sec" +"%Y-%m-%d" 2>/dev/null)
if [[ -z "$new_exp_date" ]]; then
  echo '{"status": "error", "message": "Failed to parse renewal date"}'
  exit 1
fi
new_exp_display="$new_exp_date"

# Update System Expiry
usermod -e "$new_exp_date" "$user" >/dev/null 2>&1
passwd -u "$user" >/dev/null 2>&1

# Update Database
sed -i "/^$user ssh /d" /etc/expired-users.db
echo "$user ssh $new_exp_sec" >> /etc/expired-users.db

cat <<EOF
{
  "status": "success",
  "message": "Account renewed successfully",
  "data": {
    "expired": "$new_exp_display"
  }
}
EOF
