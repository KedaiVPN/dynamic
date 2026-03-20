#!/bin/bash
# Autokill User SSH Multi-Login (Journalctl + Netstat + WS-Tunnel Map + PID Kill)
# Uses systemd journal for real-time auth data. Kills specific PIDs to handle root-owned Dropbear sessions.

# Ensure PATH is set for Cron execution
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

if [ -z "$BASH_VERSION" ]; then
	exec /bin/bash "$0" "$@"
fi

# Configuration
DEFAULT_LIMIT=1
DEFAULT_DURATION=5
LIMIT_FILE="/etc/ssh/limit-user.conf"
DURATION_FILE="/etc/ssh/autokill-duration.conf"
LOG_FILE="/root/log-limit.txt"
WS_LOG_FILE="/var/log/ws-stunnel.log"

# Ensure net-tools
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

# --- Phase 1: Build Maps ---

# Map 1: Port -> Real IP (from WS Tunnel Log)
declare -A PORT_TO_REAL_IP
if [ -f "$WS_LOG_FILE" ]; then
    while IFS="|" read -r ts action port ip; do
        if [ "$action" == "CONNECT" ]; then
            PORT_TO_REAL_IP[$port]="$ip"
        # elif [ "$action" == "DISCONNECT" ]; then
        #    unset PORT_TO_REAL_IP[$port]
        fi
    done < "$WS_LOG_FILE"
fi

# Map 2: Port -> Username (from Journalctl)
declare -A PORT_TO_USER

# Fetch recent logs from Dropbear and SSH service
RAW_LOGS=$(journalctl -u dropbear -u ssh -n 2000 --no-pager)

# Parse Dropbear
while read -r line; do
    if [[ "$line" =~ auth\ succeeded\ for\ \'([a-zA-Z0-9._-]+)\'\ from\ [0-9.]+:([0-9]+) ]]; then
        user="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[2]}"
        PORT_TO_USER[$port]="$user"
    elif [[ "$line" =~ for\ \'([a-zA-Z0-9._-]+)\'\ from\ [0-9.]+:([0-9]+) ]]; then
        user="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[2]}"
        PORT_TO_USER[$port]="$user"
    fi
done <<< "$RAW_LOGS"

# Parse OpenSSH
while read -r line; do
    if [[ "$line" =~ Accepted\ [a-zA-Z]+\ for\ ([a-zA-Z0-9._-]+)\ from\ [0-9.]+\ port\ ([0-9]+) ]]; then
        user="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[2]}"
        PORT_TO_USER[$port]="$user"
    elif [[ "$line" =~ for\ ([a-zA-Z0-9._-]+)\ from\ [0-9.]+\ port\ ([0-9]+) ]]; then
        user="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[2]}"
        PORT_TO_USER[$port]="$user"
    fi
done <<< "$RAW_LOGS"

# --- Phase 2: Count Active Sessions & Capture PIDs ---
declare -A USER_IP_COUNT
declare -A USER_PIDS

# Scan ESTABLISHED connections to sshd/dropbear
netstat -tnp 2>/dev/null | grep 'ESTABLISHED' | grep -E 'sshd|dropbear' | while read -r line; do
    foreign_addr=$(echo "$line" | awk '{print $5}')
    ip=$(echo "$foreign_addr" | cut -d: -f1)
    port=$(echo "$foreign_addr" | cut -d: -f2)
    pid_prog=$(echo "$line" | awk '{print $7}')
    pid=$(echo "$pid_prog" | cut -d/ -f1)

    user=""
    real_ip="$ip"

    # Try looking up user by remote port (which corresponds to ws-stunnel local port)
    user="${PORT_TO_USER[$port]}"

    if [[ "$ip" == "127.0.0.1" || "$ip" == "localhost" ]]; then
        # Local Connection (Tunnel)
        mapped_ip="${PORT_TO_REAL_IP[$port]}"
        if [ -n "$mapped_ip" ]; then
            real_ip="$mapped_ip"
        fi
    fi

    # If user found and not root
    if [[ -n "$user" && "$user" != "root" ]]; then
        # Output: User RealIP PID
        echo "$user $real_ip $pid"
    fi

done | sort -u | while read -r user ip pid; do
    # This loop runs in subshell if piped, but we redirect to file
    echo "$user $ip $pid"
done > /tmp/active_sessions.txt

# --- Phase 3: Enforce Limits ---
while read -r user ip pid; do
    if id -u "$user" >/dev/null 2>&1; then
         # Count
         count=${USER_IP_COUNT[$user]}
         if [ -z "$count" ]; then count=0; fi
         USER_IP_COUNT[$user]=$((count + 1))

         # Store PID
         current_pids=${USER_PIDS[$user]}
         USER_PIDS[$user]="$current_pids $pid"
    fi
done < /tmp/active_sessions.txt
rm -f /tmp/active_sessions.txt

duration=$(get_duration)

for user in "${!USER_IP_COUNT[@]}"; do
    count=${USER_IP_COUNT[$user]}
    limit=$(get_limit "$user")

    if [ "$count" -gt "$limit" ]; then
        lock_file="/tmp/lock-$user"

        # Cleanup stale lock file
        if [ -f "$lock_file" ] && ! passwd -S "$user" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
             rm -f "$lock_file"
        fi

        # Immediate Action (No Tolerance)
        date_log=`date +"%Y-%m-%d %X"`
        echo "$date_log - $user - $count IPs (Limit: $limit) - LOCKED" >> "$LOG_FILE"

        if passwd -S "$user" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
             : # Already locked
        else
             touch "$lock_file"
             usermod -L "$user"

             # KILL SPECIFIC PIDS (Works even for root-owned sessions)
             pids_to_kill=${USER_PIDS[$user]}
             if [ -n "$pids_to_kill" ]; then
                 kill -9 $pids_to_kill >/dev/null 2>&1
             fi

             # Schedule Unlock
             (sleep $(($duration * 60)) && usermod -U "$user" && rm -f "$lock_file" && sed -i "/ - $user - /d" "$LOG_FILE") >/dev/null 2>&1 &
        fi
    fi
done
