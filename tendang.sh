#!/bin/bash
# Autokill User SSH Multi-Login (PID + Netstat + WS-Tunnel Map)

if [ -z "$BASH_VERSION" ]; then
	exec /bin/bash "$0" "$@"
fi

# Configuration
DEFAULT_LIMIT=1
DEFAULT_DURATION=5
MULTILOGIN_WINDOW=600
LIMIT_FILE="/etc/ssh/limit-user.conf"
DURATION_FILE="/etc/ssh/autokill-duration.conf"
LOG_FILE="/root/log-limit.txt"
WS_LOG_FILE="/var/log/ws-stunnel.log"

# Ensure net-tools is installed
if ! command -v netstat &> /dev/null; then
    apt-get install net-tools -y > /dev/null 2>&1
fi

# --- Helper Functions ---
get_duration() {
    local duration
    duration=$(awk 'NF{print $1; exit}' "$DURATION_FILE" 2>/dev/null)
    if [ -z "$duration" ]; then
        duration=$DEFAULT_DURATION
    fi
    echo "$duration"
}

get_limit() {
    local user="$1"
    local limit
    limit=$(awk -v user="$user" '$1==user {print $2; found=1; exit} END{if(!found) print ""}' "$LIMIT_FILE" 2>/dev/null)
    if [ -z "$limit" ]; then
        limit=$DEFAULT_LIMIT
    fi
    echo "$limit"
}

# --- Phase 1: Build WS-Tunnel Port Map ---
declare -A WS_MAP
if [ -f "$WS_LOG_FILE" ]; then
    while IFS="|" read -r ts action port ip; do
        if [ "$action" == "CONNECT" ]; then
            WS_MAP[$port]="$ip"
        elif [ "$action" == "DISCONNECT" ]; then
            unset WS_MAP[$port]
        fi
    done < "$WS_LOG_FILE"
fi

# --- Phase 2: Count Active Sessions via PID + Netstat ---
declare -A USER_IP_COUNT
declare -A USER_IPS

# We scan netstat for ESTABLISHED connections to sshd/dropbear
# We use PID to identify User.
# We use Foreign Address + WS_MAP to identify Real IP.

netstat -tnp 2>/dev/null | grep 'ESTABLISHED' | grep -E 'sshd|dropbear' | while read -r line; do
    # tcp ... 127.0.0.1:22 127.0.0.1:54321 ESTABLISHED 1234/sshd: user

    # Get Foreign Address (Col 5)
    foreign_addr=$(echo "$line" | awk '{print $5}')
    ip=$(echo "$foreign_addr" | cut -d: -f1)
    port=$(echo "$foreign_addr" | cut -d: -f2)

    # Get PID (Col 7)
    pid_prog=$(echo "$line" | awk '{print $7}')
    pid=$(echo "$pid_prog" | cut -d/ -f1)

    if [ -z "$pid" ]; then continue; fi

    # Identify User from PID
    user=""
    owner=$(ps -p "$pid" -o user= 2>/dev/null)
    cmd=$(ps -p "$pid" -o command= 2>/dev/null)

    if [ "$owner" != "root" ]; then
        user="$owner"
    else
        # Handle Root-owned processes
        if [[ "$cmd" =~ sshd:\ ([a-zA-Z0-9._-]+) ]]; then
            user="${BASH_REMATCH[1]}"
        elif [[ "$cmd" == *"dropbear"* ]]; then
             # Check children
             child_pid=$(pgrep -P "$pid" | head -n 1)
             if [ -n "$child_pid" ]; then
                 child_owner=$(ps -p "$child_pid" -o user= 2>/dev/null)
                 if [ -n "$child_owner" ] && [ "$child_owner" != "root" ]; then
                     user="$child_owner"
                 fi
             fi
        fi
    fi

    # Filter Root/Empty
    if [[ -z "$user" || "$user" == "root" ]]; then continue; fi

    # Resolve IP if Localhost
    real_ip="$ip"
    if [[ "$ip" == "127.0.0.1" || "$ip" == "localhost" ]]; then
        mapped_ip="${WS_MAP[$port]}"
        if [ -n "$mapped_ip" ]; then
             real_ip="$mapped_ip"
        fi
    fi

    echo "$user|$real_ip"

done | sort -u | while IFS="|" read -r user ip; do
    # This loop runs in a subshell, so we cannot update USER_IP_COUNT directly.
    # We must output the data and read it back.
    echo "$user $ip"
done > /tmp/active_sessions.txt

# Read back
while read -r user ip; do
    # Check if user exists (uid >= 1000)
    if id -u "$user" >/dev/null 2>&1; then
        uid=$(id -u "$user")
        if [ "$uid" -ge 1000 ]; then
             count=${USER_IP_COUNT[$user]}
             if [ -z "$count" ]; then count=0; fi
             USER_IP_COUNT[$user]=$((count + 1))
        fi
    fi
done < /tmp/active_sessions.txt
rm -f /tmp/active_sessions.txt

# --- Phase 3: Enforce Limits ---
duration=$(get_duration)

for user in "${!USER_IP_COUNT[@]}"; do
    count=${USER_IP_COUNT[$user]}
    limit=$(get_limit "$user")

    if [ "$count" -gt "$limit" ]; then
        start_file="/tmp/limit-start-$user"
        lock_file="/tmp/lock-$user"

        # Cleanup stale lock
        if [ -f "$lock_file" ] && ! passwd -S "$user" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
             rm -f "$lock_file"
        fi

        # Start timer
        if [ ! -f "$start_file" ]; then
             date +%s > "$start_file"
        fi

        start_time=$(cat "$start_file" 2>/dev/null)
        now_time=$(date +%s)

        # Check tolerance
        if [ -n "$start_time" ] && [ $((now_time - start_time)) -ge $MULTILOGIN_WINDOW ]; then
             date_log=`date +"%Y-%m-%d %X"`
             echo "$date_log - $user - $count IPs (Limit: $limit)" >> "$LOG_FILE"

             if passwd -S "$user" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
                 :
             else
                 touch "$lock_file"
                 usermod -L "$user"
                 pkill -u "$user"
                 (sleep $(($duration * 60)) && usermod -U "$user" && rm -f "$lock_file") >/dev/null 2>&1 &
             fi
        fi
    else
        rm -f "/tmp/limit-start-$user"
    fi
done
