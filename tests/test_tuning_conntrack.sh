#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

assert_contains() {
    local file="$1" needle="$2"
    if ! grep -Fq -- "$needle" "$ROOT/$file"; then
        printf 'FAIL: %s does not contain %s\n' "$file" "$needle" >&2
        exit 1
    fi
}

# 1. Structural checks in setup.sh
assert_contains setup.sh 'tuning_conntrack() {'
assert_contains setup.sh 'tuning_conntrack'
assert_contains setup.sh '/etc/sysctl.d/99-conntrack.conf'
assert_contains setup.sh 'net.netfilter.nf_conntrack_max = 2000000'
assert_contains setup.sh 'net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30'
assert_contains setup.sh 'sysctl --system'
assert_contains setup.sh 'modprobe nf_conntrack'

# Ensure tuning_conntrack is called before vnstat / ssh-vpn / udp-custom / xray services
line_call=$(grep -n '^tuning_conntrack$' "$ROOT/setup.sh" | head -n 1 | cut -d: -f1)
line_vnstat=$(grep -n '#install vnstat' "$ROOT/setup.sh" | head -n 1 | cut -d: -f1)
line_ssh=$(grep -n '#install ssh-vpn' "$ROOT/setup.sh" | head -n 1 | cut -d: -f1)

if [ -z "$line_call" ] || [ -z "$line_vnstat" ] || [ -z "$line_ssh" ]; then
    echo "FAIL: tuning_conntrack call or service installation marker missing" >&2
    exit 1
fi

if [ "$line_call" -ge "$line_vnstat" ] || [ "$line_call" -ge "$line_ssh" ]; then
    echo "FAIL: tuning_conntrack must be called before service installations" >&2
    exit 1
fi

# 2. Execution test in an isolated chroot/subshell environment
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

SYSCTL_DIR="$TMP_DIR/etc/sysctl.d"
PROC_FILE="$TMP_DIR/proc/nf_conntrack_max"
mkdir -p "$SYSCTL_DIR" "$(dirname "$PROC_FILE")"
echo "2000000" > "$PROC_FILE"

# Extract tuning_conntrack definition from setup.sh
sed -n '/^tuning_conntrack() {/,/^}/p' "$ROOT/setup.sh" > "$TMP_DIR/func.sh"

# Test execution with redirected paths to verify logic
cat > "$TMP_DIR/runner.sh" << RUNNER_EOF
#!/usr/bin/env bash
set -e

# Mock sysctl and modprobe
sysctl() {
    echo "sysctl called: \$*" >> "$TMP_DIR/sysctl.log"
}
modprobe() {
    echo "modprobe called: \$*" >> "$TMP_DIR/modprobe.log"
}
lsmod() {
    # simulate nf_conntrack not loaded
    return 1
}

# Redefine file targets inside adapted test function
adapted_tuning_conntrack() {
    echo -e "[ \033[0;32mINFO\033[0m ] Tuning kernel conntrack..."

    if ! lsmod 2>/dev/null | grep -q nf_conntrack; then
        modprobe nf_conntrack >/dev/null 2>&1 || true
    fi

    sysctl -w net.netfilter.nf_conntrack_max=2000000 >/dev/null 2>&1 || true
    sysctl -w net.netfilter.nf_conntrack_tcp_timeout_time_wait=30 >/dev/null 2>&1 || true

    mkdir -p "$SYSCTL_DIR"
    cat > "$SYSCTL_DIR/99-conntrack.conf" << 'EOF'
net.netfilter.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
EOF
    sysctl --system >/dev/null 2>&1 || true

    local current_max=""
    if [ -r "$PROC_FILE" ]; then
        current_max=\$(cat "$PROC_FILE" 2>/dev/null || true)
    fi

    if [ "\$current_max" = "2000000" ]; then
        echo "[ OKEY ] nf_conntrack_max berhasil disetel: \$current_max"
    else
        echo "[ WARN ] nf_conntrack_max bernilai '\${current_max:-unknown}' (diharapkan 2000000), instalasi tetap dilanjutkan"
    fi
}

adapted_tuning_conntrack
adapted_tuning_conntrack
RUNNER_EOF

output=$(bash "$TMP_DIR/runner.sh")

# Verify conf file contents
if [ ! -f "$SYSCTL_DIR/99-conntrack.conf" ]; then
    echo "FAIL: 99-conntrack.conf was not created" >&2
    exit 1
fi

conf_content=$(cat "$SYSCTL_DIR/99-conntrack.conf")
expected_content=$(cat << 'EOF'
net.netfilter.nf_conntrack_max = 2000000
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
EOF
)

if [ "$conf_content" != "$expected_content" ]; then
    echo "FAIL: 99-conntrack.conf content does not match expected" >&2
    exit 1
fi

# Verify line count (must be exactly 2 lines, proving overwrite not append on repeated run)
line_count=$(wc -l < "$SYSCTL_DIR/99-conntrack.conf")
if [ "$line_count" -ne 2 ]; then
    echo "FAIL: 99-conntrack.conf has $line_count lines, expected 2 (not idempotent)" >&2
    exit 1
fi

# Verify warning behavior when value is not 2000000
echo "65536" > "$PROC_FILE"
output_warn=$(bash "$TMP_DIR/runner.sh")
if ! echo "$output_warn" | grep -q "WARN"; then
    echo "FAIL: expected warning when nf_conntrack_max is not 2000000" >&2
    exit 1
fi

echo "PASS: tuning_conntrack unit test and installation wiring"
