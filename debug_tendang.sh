#!/bin/bash
# Debug SSH Autokill Counting Logic
# Identical logic to tendang.sh but prints debug info instead of killing.

WS_LOG_FILE="/var/log/ws-stunnel.log"

echo "================================================"
echo "       DEBUGGING TENDANG.SH LOGIC"
echo "================================================"

# --- Phase 1: Build Maps ---
declare -A PORT_TO_REAL_IP
if [ -f "$WS_LOG_FILE" ]; then
    while IFS="|" read -r ts action port ip; do
        if [ "$action" == "CONNECT" ]; then
            PORT_TO_REAL_IP[$port]="$ip"
        fi
    done < "$WS_LOG_FILE"
fi

declare -A PORT_TO_USER
RAW_LOGS=$(journalctl -u dropbear -u ssh -n 2000 --no-pager)
while read -r line; do
    if [[ "$line" =~ for\ \'([a-zA-Z0-9._-]+)\'\ from\ [0-9.]+:([0-9]+) ]]; then
        PORT_TO_USER[${BASH_REMATCH[2]}]="${BASH_REMATCH[1]}"
    fi
done <<< "$RAW_LOGS"
while read -r line; do
    if [[ "$line" =~ for\ ([a-zA-Z0-9._-]+)\ from\ [0-9.]+\ port\ ([0-9]+) ]]; then
        PORT_TO_USER[${BASH_REMATCH[2]}]="${BASH_REMATCH[1]}"
    fi
done <<< "$RAW_LOGS"

# --- Phase 2: Count Active Sessions via Netstat ---
declare -A USER_IP_COUNT
declare -A USER_IPS

echo "[1] Scanning Netstat & Resolving..."
netstat -tnp 2>/dev/null | grep 'ESTABLISHED' | grep -E 'sshd|dropbear' | while read -r line; do
    foreign_addr=$(echo "$line" | awk '{print $5}')
    ip=$(echo "$foreign_addr" | cut -d: -f1)
    port=$(echo "$foreign_addr" | cut -d: -f2)

    user=""
    real_ip="$ip"

    if [[ "$ip" == "127.0.0.1" || "$ip" == "localhost" ]]; then
        user="${PORT_TO_USER[$port]}"
        mapped_ip="${PORT_TO_REAL_IP[$port]}"
        if [ -n "$mapped_ip" ]; then
            real_ip="$mapped_ip"
        fi
    else
        user="${PORT_TO_USER[$port]}"
    fi

    if [[ -n "$user" && "$user" != "root" ]]; then
        echo "$user $real_ip"
    fi

done | sort -u > /tmp/debug_sessions.txt

cat /tmp/debug_sessions.txt
echo ""

echo "[2] Counting Unique IPs per User..."
while read -r user ip; do
    # Simulate valid user check
    if id -u "$user" >/dev/null 2>&1; then
         count=${USER_IP_COUNT[$user]}
         if [ -z "$count" ]; then count=0; fi
         USER_IP_COUNT[$user]=$((count + 1))
    fi
done < /tmp/debug_sessions.txt

echo "[3] Final Counts & Limit Check:"
for user in "${!USER_IP_COUNT[@]}"; do
    count=${USER_IP_COUNT[$user]}

    # Get Limit
    limit=$(awk -v user="$user" '$1==user {print $2; found=1; exit} END{if(!found) print ""}' /etc/ssh/limit-user.conf 2>/dev/null)
    if [ -z "$limit" ]; then limit=1; fi # Default limit

    echo "    User: $user | Active IPs: $count | Limit: $limit"

    if [ "$count" -gt "$limit" ]; then
        echo -e "    -> \033[31mVIOLATION DETECTED! (Should be LOCKED)\033[0m"
    else
        echo -e "    -> \033[32mOK (Within Limit)\033[0m"
    fi
done

echo "================================================"
rm -f /tmp/debug_sessions.txt
