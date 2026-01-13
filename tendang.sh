#!/bin/bash
# Autokill User SSH Multi-Login (Hybrid Log + Netstat Version)
# Analyzes auth logs to map IPs to Users, then verifies with Netstat.

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
SESSION_DB="/tmp/ssh-session-db.txt"

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

# --- Phase 1: Update Session Database (The Receptionist) ---
# 1. Identify valid log files
LOGS=""
if [ -f "/var/log/auth.log" ]; then LOGS="/var/log/auth.log"; fi
if [ -f "/var/log/secure" ]; then LOGS="$LOGS /var/log/secure"; fi

# 2. Prepare Candidates
# We read existing DB + recent logs to build a candidate list of (User, IP)
CANDIDATES_FILE="/tmp/ssh-candidates.tmp"
touch "$SESSION_DB"
cat "$SESSION_DB" > "$CANDIDATES_FILE"

if [ -n "$LOGS" ]; then
    # We parse the last 2000 lines to catch recent logins
    # Pattern 1: Dropbear "Password auth succeeded for 'user' from 1.2.3.4"
    tail -n 2000 $LOGS | grep "Password auth succeeded for" | \
    sed -E "s/.*for '([a-zA-Z0-9._-]+)' from ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1 \2/" >> "$CANDIDATES_FILE"

    # Pattern 2: OpenSSH "Accepted password for user from 1.2.3.4"
    tail -n 2000 $LOGS | grep "Accepted password for" | \
    sed -E "s/.*for ([a-zA-Z0-9._-]+) from ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1 \2/" >> "$CANDIDATES_FILE"

    # Pattern 3: OpenSSH "Accepted publickey for user from 1.2.3.4"
    tail -n 2000 $LOGS | grep "Accepted publickey for" | \
    sed -E "s/.*for ([a-zA-Z0-9._-]+) from ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*/\1 \2/" >> "$CANDIDATES_FILE"
fi

# 3. Clean and Unique Candidates
# Sort and Unique to remove duplicates
sort -u "$CANDIDATES_FILE" -o "$CANDIDATES_FILE"

# --- Phase 2: Validate with Netstat (The Checker) ---
# 1. Get currently active (ESTABLISHED) remote IPs attached to SSH/Dropbear ports
# We grep ESTABLISHED. We assume standard SSH ports might be used or any port.
# But simply "foreign address" of any ESTABLISHED connection is a good enough proxy
# if we cross-reference with the username login history.
ACTIVE_IPS_FILE="/tmp/ssh-active-ips.tmp"
# sed 's/:[0-9]*$//' removes the port number from IP:Port
netstat -tn 2>/dev/null | grep 'ESTABLISHED' | awk '{print $5}' | sed 's/:[0-9]*$//' | sort -u > "$ACTIVE_IPS_FILE"

# 2. Filter Candidates: Only keep if IP is currently active
NEW_DB_FILE="/tmp/ssh-session-db.new"
truncate -s 0 "$NEW_DB_FILE"

while read -r user ip; do
    # Skip malformed lines
    if [[ -z "$user" || -z "$ip" ]]; then continue; fi

    # Check if this IP is in the active list
    if grep -qF "$ip" "$ACTIVE_IPS_FILE"; then
        echo "$user $ip" >> "$NEW_DB_FILE"
    fi
done < "$CANDIDATES_FILE"

# 3. Update the persistent DB
mv "$NEW_DB_FILE" "$SESSION_DB"

# --- Phase 3: Enforce Limits ---
declare -A USER_IP_COUNT
declare -A USER_IPS

# 1. Count Active IPs per User
while read -r user ip; do
    # Only process valid system users with UID >= 1000 (avoid root/daemon)
    if id -u "$user" >/dev/null 2>&1; then
        uid=$(id -u "$user")
        if [ "$uid" -ge 1000 ]; then
            count=${USER_IP_COUNT[$user]}
            if [ -z "$count" ]; then count=0; fi

            # Increment
            USER_IP_COUNT[$user]=$((count + 1))

            # Store IPs for logging
            USER_IPS[$user]="${USER_IPS[$user]} $ip"
        fi
    fi
done < "$SESSION_DB"

# 2. Check Limits
duration=$(get_duration)

for user in "${!USER_IP_COUNT[@]}"; do
    count=${USER_IP_COUNT[$user]}
    limit=$(get_limit "$user")

    if [ "$count" -gt "$limit" ]; then
        # VIOLATION DETECTED
        start_file="/tmp/limit-start-$user"
        lock_file="/tmp/lock-$user"

        # Clean up stale lock file if user is unlocked manually
        if [ -f "$lock_file" ] && ! passwd -S "$user" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
             rm -f "$lock_file"
        fi

        # Start Tolerance Timer
        if [ ! -f "$start_file" ]; then
             date +%s > "$start_file"
        fi

        start_time=$(cat "$start_file" 2>/dev/null)
        now_time=$(date +%s)

        # Check Tolerance Window
        if [ -n "$start_time" ] && [ $((now_time - start_time)) -ge $MULTILOGIN_WINDOW ]; then
             # Log the event
             date_log=`date +"%Y-%m-%d %X"`
             echo "$date_log - $user - $count IPs (Limit: $limit)" >> "$LOG_FILE"

             # Enforce Lock
             if passwd -S "$user" 2>/dev/null | awk '{print $2}' | grep -q "L"; then
                 : # Already locked
             else
                 touch "$lock_file"
                 usermod -L "$user"
                 pkill -u "$user"

                 # Schedule Unlock
                 (sleep $(($duration * 60)) && usermod -U "$user" && rm -f "$lock_file") >/dev/null 2>&1 &
             fi
        fi
    else
        # User is safe, reset timer
        rm -f "/tmp/limit-start-$user"
    fi
done

# Cleanup temporary files
rm -f "$CANDIDATES_FILE" "$ACTIVE_IPS_FILE" "$NEW_DB_FILE"
