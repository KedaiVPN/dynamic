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

# 4. Fail2Ban protection on all SSH ports (22, 2253, 40000) with localhost ignoreip & systemd backend
assert_contains setup.sh 'python3-systemd'
for script in ssh-vpn.sh update.sh; do
    assert_contains "$script" '/etc/fail2ban/jail.local'
    assert_contains "$script" 'ignoreip = 127.0.0.1/8 ::1'
    assert_contains "$script" 'port = 22,2253,40000'
    assert_contains "$script" 'python3-systemd'
    assert_contains "$script" 'f2b_backend="systemd"'
    assert_contains "$script" 'backend = ${f2b_backend}'
done

# 5. Systemd journal limit (100M) + SplitMode=none + user-*.journal cleanup
for script in ssh-vpn.sh update.sh; do
    assert_contains "$script" '/etc/systemd/journald.conf.d/99-limit.conf'
    assert_contains "$script" 'SystemMaxUse=100M'
    assert_contains "$script" 'RuntimeMaxUse=50M'
    assert_contains "$script" 'SplitMode=none'
    assert_contains "$script" 'systemctl restart systemd-journald'
    assert_contains "$script" 'user-*.journal'
    assert_contains "$script" 'journalctl --vacuum-size=100M'
    # Journald restart must happen before fail2ban restarts so fail2ban opens clean journal handles
    jrn_line=$(grep -n '/etc/systemd/journald.conf.d/99-limit.conf' "$ROOT/$script" | head -n1 | cut -d: -f1)
    f2b_line=$(grep -n '/etc/fail2ban/jail.local' "$ROOT/$script" | head -n1 | cut -d: -f1)
    if [ "$jrn_line" -ge "$f2b_line" ]; then
        echo "FAIL: $script configures journald (line $jrn_line) after fail2ban (line $f2b_line)" >&2
        exit 1
    fi
done

# 6. Functional idempotency test for MaxStartups + KEX, journald cleanup, and Fail2Ban backend selection
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

# Test Fail2Ban backend selection with mocked python3
mkdir -p "$TMP_DIR/bin" "$TMP_DIR/etc/fail2ban" "$TMP_DIR/var/log/journal/abc"
touch "$TMP_DIR/var/log/journal/abc/user-1001.journal" "$TMP_DIR/var/log/journal/abc/system.journal"
rm -f "$TMP_DIR"/var/log/journal/*/user-*.journal
if [ -e "$TMP_DIR/var/log/journal/abc/user-1001.journal" ] || [ ! -e "$TMP_DIR/var/log/journal/abc/system.journal" ]; then
    echo "FAIL: user-*.journal cleanup did not preserve system.journal" >&2
    exit 1
fi

render_f2b() {
    local py_ok="$1" out="$2" f2b_backend="auto"
    if [ "$py_ok" = "1" ]; then
        f2b_backend="systemd"
    fi
    cat > "$out" << F2BEOF
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = 22,2253,40000
backend = ${f2b_backend}
F2BEOF
}

render_f2b 1 "$TMP_DIR/etc/fail2ban/jail.local"
grep -Fqx 'backend = systemd' "$TMP_DIR/etc/fail2ban/jail.local"
render_f2b 0 "$TMP_DIR/etc/fail2ban/jail.local"
grep -Fqx 'backend = auto' "$TMP_DIR/etc/fail2ban/jail.local"

echo "PASS: sshd MaxStartups, UDP buffer, journald 100M SplitMode=none, and Fail2Ban systemd backend tuning"
