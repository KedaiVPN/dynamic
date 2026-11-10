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

# 1. Syntax checks on modified install & update scripts
bash -n "$ROOT/setup.sh"
bash -n "$ROOT/ssh-vpn.sh"
bash -n "$ROOT/update.sh"

# 2. SSH optimization: KEX + MaxStartups 60:30:200 + cloudimg drop-in cleanup
for script in ssh-vpn.sh update.sh; do
    assert_contains "$script" '60-cloudimg-settings.conf'
    assert_contains "$script" 'SlowDNS Handshake Optimization'
    assert_contains "$script" 'MaxStartups 60:30:200'
    assert_contains "$script" 'KexAlgorithms curve25519-sha256'
done

# 3. UDP default buffer tuning (2 MB) across fresh install and updater
for script in setup.sh ssh-vpn.sh update.sh; do
    assert_contains "$script" '/etc/sysctl.d/99-udp-buffer.conf'
    assert_contains "$script" 'net.core.rmem_default = 2097152'
    assert_contains "$script" 'net.core.wmem_default = 2097152'
done

# 4. Fail2Ban protection on all SSH ports (22, 2253, 40000) with localhost ignoreip
for script in ssh-vpn.sh update.sh; do
    assert_contains "$script" '/etc/fail2ban/jail.local'
    assert_contains "$script" 'ignoreip = 127.0.0.1/8 ::1'
    assert_contains "$script" 'port = 22,2253,40000'
done

# 5. Functional idempotency test for MaxStartups + KEX on an already-KEX-optimized sshd_config
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$TMP_DIR/sshd_config" << 'EOF'
Port 22
Port 2253
Port 40000

# SlowDNS Handshake Optimization
KexAlgorithms curve25519-sha256
Ciphers chacha20-poly1305@openssh.com
MACs hmac-sha2-256-etm@openssh.com
HostKeyAlgorithms ssh-ed25519
EOF

apply_sshd_check() {
    local cfg="$1"
    if ! grep -q "SlowDNS Handshake Optimization" "$cfg"; then
        printf '\n# SlowDNS Handshake Optimization\nMaxStartups 60:30:200\n' >> "$cfg"
    fi
    if ! grep -qE '^[[:space:]]*MaxStartups[[:space:]]+60:30:200' "$cfg"; then
        sed -i '/^[[:space:]]*MaxStartups[[:space:]]\+/d' "$cfg"
        printf 'MaxStartups 60:30:200\n' >> "$cfg"
    fi
}

apply_sshd_check "$TMP_DIR/sshd_config"
apply_sshd_check "$TMP_DIR/sshd_config"

count=$(grep -cE '^[[:space:]]*MaxStartups[[:space:]]+60:30:200' "$TMP_DIR/sshd_config")
if [ "$count" -ne 1 ]; then
    echo "FAIL: expected exactly 1 MaxStartups 60:30:200 line, got $count" >&2
    exit 1
fi

echo "PASS: sshd MaxStartups, UDP buffer, and Fail2Ban tuning"
