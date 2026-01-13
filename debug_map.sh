#!/bin/bash
# Debug SSH Autokill Mapping Logic
# Run this to see why connections are (or aren't) being mapped.

WS_LOG_FILE="/var/log/ws-stunnel.log"
declare -A WS_MAP

echo "================================================"
echo "       DEBUGGING SSH AUTOKILL MAPPING"
echo "================================================"

echo "[1] Reading WS-Tunnel Log: $WS_LOG_FILE"
if [ -f "$WS_LOG_FILE" ]; then
    count=0
    # Read line by line to debug parsing
    while IFS="|" read -r ts action port ip; do
        if [ "$action" == "CONNECT" ]; then
            WS_MAP[$port]="$ip"
            ((count++))
        elif [ "$action" == "DISCONNECT" ]; then
            unset WS_MAP[$port]
            ((count--))
        fi
    done < "$WS_LOG_FILE"
    echo "    -> Loaded current map. Active Tunnels tracked: ${#WS_MAP[@]}"
else
    echo "    -> ERROR: Log file not found!"
    exit 1
fi

echo ""
echo "[2] Scanning Netstat for Local SSH Connections..."
found=0
netstat -tnp 2>/dev/null | grep 'ESTABLISHED' | grep -E 'sshd|dropbear' | while read -r line; do
    foreign_addr=$(echo "$line" | awk '{print $5}')
    ip=$(echo "$foreign_addr" | cut -d: -f1)
    port=$(echo "$foreign_addr" | cut -d: -f2)
    pid_prog=$(echo "$line" | awk '{print $7}')

    if [[ "$ip" == "127.0.0.1" || "$ip" == "localhost" ]]; then
        ((found++))
        mapped="${WS_MAP[$port]}"
        echo "    Found Local Connection: 127.0.0.1:$port ($pid_prog)"

        if [ -n "$mapped" ]; then
            echo -e "    -> \033[32mSUCCESS MATCH\033[0m: Maps to Real IP \033[1m$mapped\033[0m"
        else
            echo -e "    -> \033[31mFAILED MATCH\033[0m: Port $port not found in active WS_MAP."
            echo "       (Maybe connection is old, or log was cleared, or timing mismatch?)"
        fi
    fi
done

if [ $found -eq 0 ]; then
    echo "    -> No localhost connections found in Netstat."
fi

echo ""
echo "================================================"
echo "Done."
