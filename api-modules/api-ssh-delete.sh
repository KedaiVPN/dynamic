#!/bin/bash
# API Module: SSH Delete
# Args: user

user="$1"

if [[ -z "$user" ]]; then
  echo '{"status": "error", "message": "Missing username"}'
  exit 1
fi

if ! id "$user" >/dev/null 2>&1; then
  echo '{"status": "error", "message": "User does not exist"}'
  exit 1
fi

userdel -f "$user" >/dev/null 2>&1
sed -i "/^$user ssh /d" /etc/expired-users.db
sed -i "/^$user /d" /etc/ssh/limit-user.conf

cat <<EOF
{
  "status": "success",
  "message": "Account deleted successfully"
}
EOF
