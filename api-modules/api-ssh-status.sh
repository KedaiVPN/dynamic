#!/bin/bash
# API Module: SSH Status
# Args: user

user="$1"

if [[ -z "$user" ]]; then
  echo '{"status": "error", "message": "Missing required arguments"}'
  exit 1
fi

# Check if user exists
if ! id "$user" >/dev/null 2>&1; then
  echo '{"status": "error", "message": "User not found"}'
  exit 1
fi

# Check Lock Status
# passwd -S output format: username status(L/NP/P) last_password_change_date min_days max_days warning_days inactivity_days
status_output=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
if [[ "$status_output" == "L" ]]; then
    status_account="LOCKED"
else
    status_account="UNLOCKED"
fi

# Get IP limit from /etc/ssh/limit-user.conf
limit_file="/etc/ssh/limit-user.conf"
iplimit=$(awk -v u="$user" '$1==u {print $2}' "$limit_file" 2>/dev/null)
if [[ -z "$iplimit" ]]; then
    iplimit="0" # No limit or default
fi

# Get expiry date from /etc/expired-users.db
exp_timestamp=$(awk -v u="$user" '$1==u && $2=="ssh" {print $3}' /etc/expired-users.db 2>/dev/null | head -n 1)
if [[ -n "$exp_timestamp" ]]; then
    exp_date=$(date -d "@$exp_timestamp" +"%Y-%m-%d")
else
    # Fallback to chage if not found in db
    exp_date=$(chage -l "$user" | grep "Account expires" | awk -F': ' '{print $2}')
    if [[ "$exp_date" == "never" ]]; then
        exp_date="never"
    else
        exp_date=$(date -d "$exp_date" +"%Y-%m-%d" 2>/dev/null || echo "unknown")
    fi
fi

# JSON Response
cat <<EOF
{
  "status": "success",
  "data": {
    "protocol": "ssh",
    "username": "$user",
    "status_account": "$status_account",
    "ip_limit": "$iplimit",
    "expired": "$exp_date"
  }
}
EOF
