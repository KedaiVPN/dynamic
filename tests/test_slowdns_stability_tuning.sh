#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 1. Syntax checks on all modified scripts
for script in setup.sh ssh-vpn.sh update.sh restart.sh slowdns.sh factory-reset.sh; do
    bash -n "$ROOT/$script"
done

# 2. Extract slowdns-watchdog.sh directly from slowdns.sh and run functional scenarios
mkdir -p "$TMP/bin" "$TMP/proc/99999" "$TMP/run" "$TMP/state"
sed -n "/cat > \"\$SLOWDNS_WATCHDOG_BIN\" <<'WDBIN'/,/^WDBIN$/p" "$ROOT/slowdns.sh" \
    | sed '1d;$d' \
    | sed "s|/proc/\$pid|$TMP/proc/\$pid|g; s|/run/slowdns-watchdog-|$TMP/run/slowdns-watchdog-|g" \
    > "$TMP/watchdog.sh"
chmod 755 "$TMP/watchdog.sh"
bash -n "$TMP/watchdog.sh"

cat > "$TMP/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  is-active) exit 0 ;;
  show)
    if [[ "$*" == *MainPID* ]]; then echo 99999; else echo inv-123; fi
    ;;
  restart)
    echo "$*" >> "$MOCK_STATE/restarts"
    exit 0
    ;;
  *) exit 0 ;;
esac
EOF

cat > "$TMP/bin/ss" <<'EOF'
#!/usr/bin/env bash
n="${MOCK_ACTIVE:-0}"
for ((i=0; i<n; i++)); do
    echo "ESTAB 0 0 127.0.0.1:5000${i} 127.0.0.1:22 users:((\"slowdns\",pid=99999,fd=$((10+i))))"
done
EOF

cat > "$TMP/bin/journalctl" <<'EOF'
#!/usr/bin/env bash
b="${MOCK_BEGINS:-0}"
e="${MOCK_ENDS:-0}"
for ((i=0; i<b; i++)); do echo 'begin session'; done
for ((i=0; i<e; i++)); do echo 'end session'; done
EOF

cat > "$TMP/bin/python3" <<'EOF'
#!/usr/bin/env bash
echo "${MOCK_CPU:-0.0}"
EOF

cat > "$TMP/bin/date" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  +%H) echo "${MOCK_HOUR:-14}" ;;
  +%M) echo "${MOCK_MIN:-05}" ;;
  +%F) echo "2026-11-11" ;;
  *) /bin/date "$@" ;;
esac
EOF

cat > "$TMP/bin/logger" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$MOCK_STATE/logs"
EOF

chmod 755 "$TMP/bin"/*

run_wd() {
    PATH="$TMP/bin:$PATH" MOCK_STATE="$TMP/state" \
    MOCK_ACTIVE="$1" MOCK_BEGINS="$2" MOCK_ENDS="$3" MOCK_CPU="$4" \
    MOCK_HOUR="${5:-14}" MOCK_MIN="${6:-05}" \
    bash "$TMP/watchdog.sh"
}

: > "$TMP/state/restarts"

# Case A: Active user present (1) with 10 zombies during daytime -> must NOT restart
run_wd 1 15 4 "20.0" 14 05
if [[ -s "$TMP/state/restarts" ]]; then
    echo "FAIL: watchdog restarted slowdns while active user was connected" >&2
    exit 1
fi

# Case B: Zero active users, 6 zombies, low CPU -> MUST restart
run_wd 0 10 4 "1.0" 14 05
if [[ "$(wc -l < "$TMP/state/restarts")" -ne 1 ]]; then
    echo "FAIL: watchdog did not restart slowdns with 0 users and 6 zombies" >&2
    exit 1
fi

# Case C: Zero active users, 1 zombie, high idle CPU (15%) -> MUST restart
run_wd 0 5 4 "15.0" 14 05
if [[ "$(wc -l < "$TMP/state/restarts")" -ne 2 ]]; then
    echo "FAIL: watchdog did not restart slowdns with 0 users and 15% idle CPU" >&2
    exit 1
fi

# Case D: Zero active users, 1 zombie, low CPU (1%) -> must NOT restart
run_wd 0 5 4 "1.0" 14 05
if [[ "$(wc -l < "$TMP/state/restarts")" -ne 2 ]]; then
    echo "FAIL: watchdog restarted slowdns unnecessarily when healthy" >&2
    exit 1
fi

# Case E: Quiet hour 04:05 with active user and 16 zombies -> MUST restart once, not twice
run_wd 1 20 3 "5.0" 04 05
run_wd 1 20 3 "5.0" 04 06
if [[ "$(wc -l < "$TMP/state/restarts")" -ne 3 ]]; then
    echo "FAIL: quiet-hour safety cleanup did not run exactly once" >&2
    exit 1
fi

# 3. Extract enable-rps.sh from setup.sh and verify bitmask computation for 2 CPUs vs 1 CPU
sed -n "/cat > \/usr\/local\/sbin\/enable-rps\.sh << 'EOF'/,/^EOF$/p" "$ROOT/setup.sh" \
    | sed '1d;$d' > "$TMP/enable-rps.sh"
chmod 755 "$TMP/enable-rps.sh"
bash -n "$TMP/enable-rps.sh"

mkdir -p "$TMP/sys/class/net/ens18/queues/rx-0" "$TMP/sys/class/net/lo/queues/rx-0"
echo "0" > "$TMP/sys/class/net/ens18/queues/rx-0/rps_cpus"
echo "0" > "$TMP/sys/class/net/lo/queues/rx-0/rps_cpus"
sed -i "s|/sys/class/net|$TMP/sys/class/net|g" "$TMP/enable-rps.sh"

cat > "$TMP/bin/nproc" <<'EOF'
#!/usr/bin/env bash
echo "${MOCK_CPUS:-2}"
EOF
chmod 755 "$TMP/bin/nproc"

PATH="$TMP/bin:$PATH" MOCK_CPUS=2 bash "$TMP/enable-rps.sh"
[[ "$(cat "$TMP/sys/class/net/ens18/queues/rx-0/rps_cpus")" == "3" ]]
[[ "$(cat "$TMP/sys/class/net/lo/queues/rx-0/rps_cpus")" == "0" ]]

# 4. Verify sync-watchdog is a no-op when slowdns.service is inactive
cat > "$TMP/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  is-active) exit 3 ;;
  *) exit 0 ;;
esac
EOF
mkdir -p "$TMP/wd_inactive"
PATH="$TMP/bin:$PATH" \
SLOWDNS_SERVICE="$TMP/wd_inactive/slowdns.service" \
SLOWDNS_WATCHDOG_BIN="$TMP/wd_inactive/slowdns-watchdog.sh" \
SLOWDNS_WATCHDOG_SERVICE="$TMP/wd_inactive/slowdns-watchdog.service" \
SLOWDNS_WATCHDOG_TIMER="$TMP/wd_inactive/slowdns-watchdog.timer" \
bash "$ROOT/slowdns.sh" sync-watchdog
[[ ! -e "$TMP/wd_inactive/slowdns-watchdog.sh" ]]

echo 'PASS: SlowDNS stability tuning (watchdog, RPS, BadVPN systemd, UDP buffers)'
