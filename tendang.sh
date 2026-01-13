#!/bin/bash
# Autokill User SSH Multi-Login (Netstat Version)

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

# Ensure net-tools is installed for netstat
if ! command -v netstat &> /dev/null; then
    apt-get install net-tools -y > /dev/null 2>&1
fi

# Functions to get config
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

# Collect valid users (UID >= 1000) or from config
# Using /etc/passwd is safer to get all valid users
users=$(awk -F: '$3 >= 1000 {print $1}' /etc/passwd)

# Prepare to count connections
declare -A user_counts

# Get all PIDs of established connections for sshd or dropbear
# We filter for ESTABLISHED and program names sshd or dropbear
# Format: Proto ... PID/Program name
pids=$(netstat -tnp 2>/dev/null | grep 'ESTABLISHED' | grep -E 'sshd|dropbear' | awk '{print $7}' | cut -d/ -f1 | sort -u)

for pid in $pids; do
    if [ -z "$pid" ]; then continue; fi

    # Identify User for this PID
    user=""
    owner=$(ps -p "$pid" -o user= 2>/dev/null)
    cmd=$(ps -p "$pid" -o command= 2>/dev/null)

    if [ -z "$owner" ]; then continue; fi

    if [ "$owner" != "root" ]; then
        # If process is owned by a regular user, it's their connection
        user="$owner"
    else
        # Process is owned by root. Analyze Command or Children.

        # Case 1: OpenSSH (sshd: username [priv])
        if [[ "$cmd" =~ sshd:\ ([a-zA-Z0-9._-]+) ]]; then
            user="${BASH_REMATCH[1]}"
        fi

        # Case 2: Dropbear (parent is root, child is user)
        if [[ -z "$user" && "$cmd" == *"dropbear"* ]]; then
            # Find child process
            child_pid=$(pgrep -P "$pid" | head -n 1)
            if [ -n "$child_pid" ]; then
                child_owner=$(ps -p "$child_pid" -o user= 2>/dev/null)
                if [ -n "$child_owner" ] && [ "$child_owner" != "root" ]; then
                    user="$child_owner"
                fi
            fi
        fi
    fi

    # Increment count if user is valid and found
    if [ -n "$user" ]; then
        if [[ " $users " =~ " $user " ]]; then
             current_count=${user_counts[$user]}
             if [ -z "$current_count" ]; then current_count=0; fi
             user_counts[$user]=$((current_count + 1))
        fi
    fi
done

# Check Limits and Enforce
j=0
duration=$(get_duration)

for user in $users; do
    count=${user_counts[$user]}
    if [ -z "$count" ]; then count=0; fi

    limit=$(get_limit "$user")

    if [ "$count" -gt "$limit" ]; then
        # User exceeded limit
        start_file="/tmp/limit-start-$user"
        lock_file="/tmp/lock-$user"

        # If user is already locked, check if we should clean up lock file (if manually unlocked?)
        # But here we rely on the logic: If locked, we don't need to re-lock immediately,
        # unless we want to extend? The original script checks "passwd -S ... L".

        if [ -f "$lock_file" ] && ! passwd -S "$user" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
             rm -f "$lock_file"
        fi

        # Start timer if not started
        if [ ! -f "$start_file" ]; then
             date +%s > "$start_file"
        fi

        start_time=$(cat "$start_file" 2>/dev/null)
        now_time=$(date +%s)

        # Check tolerance window
        if [ -n "$start_time" ] && [ $((now_time - start_time)) -ge $MULTILOGIN_WINDOW ]; then

            # Log violation
            date_log=`date +"%Y-%m-%d %X"`
            echo "$date_log - $user - $count (Limit: $limit)" >> "$LOG_FILE"

            # Check if already locked
            if passwd -S "$user" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
                : # Already locked
            else
                # ACTION: Lock and Kill
                touch "$lock_file"
                usermod -L "$user"

                # Kill user processes to disconnect them
                pkill -u "$user"

                # Schedule unlock
                (sleep $(($duration * 60)) && usermod -U "$user" && rm -f "$lock_file") >/dev/null 2>&1 &
            fi
        fi
    else
        # User is within limit, reset timer
        rm -f "/tmp/limit-start-$user"
    fi
done
