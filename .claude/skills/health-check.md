---
name: health-check
description: Comprehensive system health check. Run on demand or scheduled.
user-invocable: true
---

# System Health Check

Run a full system health assessment and report results.

## Checks

```bash
echo "=== IDENTITY ==="
hostname -f && date -Is && uname -r

echo "=== UPTIME & LOAD ==="
uptime

echo "=== MEMORY ==="
free -h

echo "=== DISK ==="
df -h --type=ext4 --type=btrfs --type=xfs --type=vfat 2>/dev/null || df -h
btrfs filesystem usage / 2>/dev/null || true

echo "=== FAILED SERVICES ==="
systemctl --failed --no-pager

echo "=== TOP CPU ==="
ps aux --sort=-%cpu | head -6

echo "=== TOP MEMORY ==="
ps aux --sort=-%mem | head -6

echo "=== LISTENING PORTS ==="
ss -tlnp

echo "=== DOCKER (if present) ==="
docker ps --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "Docker not installed"

echo "=== K3S (if present) ==="
k3s kubectl get pods -A --no-headers 2>/dev/null | awk '{print $1, $2, $4}' || echo "K3s not installed"

echo "=== TAILSCALE ==="
tailscale status --json 2>/dev/null | head -20 || echo "Tailscale not installed"

echo "=== PENDING UPDATES ==="
apt list --upgradable 2>/dev/null | tail -n +2 | wc -l

echo "=== REBOOT REQUIRED ==="
[ -f /var/run/reboot-required ] && echo "YES — reboot required" || echo "No"

echo "=== SECURITY ==="
last -5 --time-format iso
grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 || true
```

## Output

Summarize as a structured report. Flag anything abnormal with ⚠️.
If any critical issue is found, recommend immediate action.
