---
name: system-upgrade
description: Perform a full system upgrade with safety checks and documentation.
argument-hint: "[--security-only] [--unattended]"
user-invocable: true
---

# System Upgrade Skill

## Arguments
- `--security-only` — Only apply security updates
- `--unattended` — Skip confirmation prompts (for cron use)

## Procedure

### 1. Pre-flight
```bash
echo "=== Pre-flight check ==="
apt update 2>&1
UPGRADABLE=$(apt list --upgradable 2>/dev/null | tail -n +2)
echo "$UPGRADABLE"
COUNT=$(echo "$UPGRADABLE" | grep -c . || true)
echo "--- $COUNT packages upgradable ---"
apt-mark showhold
[ -f /var/run/reboot-required ] && echo "⚠️ Reboot already required before upgrade"
```

### 2. Preview
```bash
apt upgrade --dry-run 2>&1
```

If `--security-only`:
```bash
apt upgrade --dry-run -o Dir::Etc::SourceList=/etc/apt/sources.list.d/ubuntu-security.list 2>&1
```

### 3. Confirm (unless --unattended)
Show the dry-run output and ask for confirmation.

### 4. Execute
```bash
DEBIAN_FRONTEND=noninteractive apt upgrade -y 2>&1
```

### 5. Post-flight
```bash
echo "=== Post-flight ==="
apt list --upgradable 2>/dev/null | tail -n +2
systemctl --failed --no-pager
[ -f /var/run/reboot-required ] && echo "⚠️ Reboot required"
needrestart -b 2>/dev/null || true
```

### 6. Document
Invoke the `doc-update` skill with upgrade summary.
