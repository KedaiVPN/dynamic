#!/bin/bash
# Debug SSH Autokill Triple Map Logic
# Analyzes: Auth Log (User<->Port) + WS Log (IP<->Port) + Netstat (Active Port)

AUTH_LOG="/var/log/auth.log" # Adjust if needed
WS_LOG="/var/log/ws-stunnel.log"

declare -A PORT_USER
declare -A PORT_IP

echo "================================================"
echo "       DEBUGGING TRIPLE MAP LOGIC"
echo "================================================"

echo ""
echo "[1] Scanning Auth Log (Last 50 entries)..."
echo "    Looking for: 'Password auth succeeded for ... from ...:PORT'"
echo "------------------------------------------------"
# Parse Dropbear
while read -r line; do
    if [[ "$line" =~ for\ \'([a-zA-Z0-9._-]+)\'\ from\ [0-9.]+:([0-9]+) ]]; then
        user="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[2]}"
        PORT_USER[$port]="$user"
        echo "    -> Found Auth: Port $port = User '$user'"
    fi
done < <(grep "Password auth succeeded for" $AUTH_LOG | tail -n 50)

# Parse OpenSSH
while read -r line; do
    if [[ "$line" =~ for\ ([a-zA-Z0-9._-]+)\ from\ [0-9.]+\ port\ ([0-9]+) ]]; then
        user="${BASH_REMATCH[1]}"
        port="${BASH_REMATCH[2]}"
        PORT_USER[$port]="$user"
        echo "    -> Found Auth: Port $port = User '$user'"
    fi
done < <(grep "Accepted .* for" $AUTH_LOG | tail -n 50)

echo "    Total Authenticated Ports Loaded: ${#PORT_USER[@]}"


echo ""
echo "[2] Scanning WS-Tunnel Log (Last 50 entries)..."
echo "    Looking for: 'CONNECT|PORT|IP'"
echo "------------------------------------------------"
if [ -f "$WS_LOG" ]; then
    while IFS="|" read -r ts action port ip; do
        if [ "$action" == "CONNECT" ]; then
            PORT_IP[$port]="$ip"
            # Only print last few to avoid spam, or print all if debugging small log
        elif [ "$action" == "DISCONNECT" ]; then
            unset PORT_IP[$port]
        fi
    done < <(tail -n 50 $WS_LOG)

    # Print what's currently in map from the tail
    for port in "${!PORT_IP[@]}"; do
        echo "    -> Found Tunnel: Port $port = IP ${PORT_IP[$port]}"
    done
else
    echo "    -> ERROR: WS Log not found."
fi
echo "    Total Tunnel Ports Loaded (from tail): ${#PORT_IP[@]}"


echo ""
echo "[3] Scanning Netstat (Active Connections)..."
echo "    Looking for: '127.0.0.1:PORT' ESTABLISHED"
echo "------------------------------------------------"
netstat -tnp 2>/dev/null | grep 'ESTABLISHED' | grep -E 'sshd|dropbear' | while read -r line; do
    foreign_addr=$(echo "$line" | awk '{print $5}')
    ip=$(echo "$foreign_addr" | cut -d: -f1)
    port=$(echo "$foreign_addr" | cut -d: -f2)
    pid_prog=$(echo "$line" | awk '{print $7}')

    echo "    Checking Connection: $foreign_addr ($pid_prog)"

    # Check User Map
    user="${PORT_USER[$port]}"
    if [ -n "$user" ]; then
        echo -e "      - Auth Map: \033[32mFOUND\033[0m -> User '$user'"
    else
        echo -e "      - Auth Map: \033[31mMISSING\033[0m (Port $port not in recent auth logs)"
    fi

    # Check IP Map
    if [[ "$ip" == "127.0.0.1" ]]; then
        real_ip="${PORT_IP[$port]}"
        if [ -n "$real_ip" ]; then
            echo -e "      - WS Map  : \033[32mFOUND\033[0m -> Real IP '$real_ip'"
        else
            echo -e "      - WS Map  : \033[31mMISSING\033[0m (Port $port not in recent tunnel logs)"
        fi
    else
        echo "      - Direct IP : $ip"
    fi

    if [[ -n "$user" ]]; then
        echo -e "      -> \033[1;32mRESULT: $user | ${real_ip:-$ip}\033[0m"
    fi
    echo ""
done

echo "================================================"
echo "Done."
