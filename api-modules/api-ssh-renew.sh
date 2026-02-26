#!/bin/bash
# API Module: SSH Renew
# Args: user add_days quota iplimit

user="$1"
add_days="$2"
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

# Calculate new expiry
current_exp_str=$(chage -l "$user" | grep "Account expires" | cut -d: -f2)
if [[ "$current_exp_str" == *"never"* ]]; then
    current_exp_sec=$(date +%s)
else
    current_exp_sec=$(date -d "$current_exp_str" +%s)
fi

now=$(date +%s)
# Logic: If expired, renew from NOW. If active, renew from current expiry.
# User prompt: "Script harus menambahkan hari ke masa aktif yang ada."
if [[ $current_exp_sec -lt $now ]]; then
    base_sec=$now
else
    base_sec=$current_exp_sec
fi

add_sec=$((add_days * 86400))
new_exp_sec=$((base_sec + add_sec))
new_exp_date=$(date -d "@$new_exp_sec" +"%Y-%m-%d")
new_exp_display=$(date -d "@$new_exp_sec" +"%Y-%m-%d")

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
