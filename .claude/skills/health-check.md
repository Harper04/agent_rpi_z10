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
# Note: no swap is intentional on this system — do not flag it.

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

echo "=== BTRFS SNAPSHOTS ==="
SNAP_DIR="${BTRFS_SNAPSHOT_DIR:-/.snapshots}"
if findmnt -t btrfs / -n >/dev/null 2>&1 && [ -d "$SNAP_DIR" ]; then
  latest=$(ls -1d "$SNAP_DIR"/root-????-??-?? 2>/dev/null | sort | tail -1)
  count=$(ls -1d "$SNAP_DIR"/root-????-??-?? 2>/dev/null | wc -l)
  if [ -n "$latest" ]; then
    echo "Latest: ${latest##*/}  |  Total: $count"
    sudo btrfs subvolume show "$latest" 2>/dev/null | grep -E 'Creation time|UUID' || true
  else
    echo "No snapshots found in $SNAP_DIR"
  fi
else
  echo "Not a btrfs root or no snapshot directory"
fi

echo "=== CONFIG DRIFT ==="
REPO_ROOT="$(git -C /home/tomjaster/sysadmin-agent rev-parse --show-toplevel 2>/dev/null || echo /home/tomjaster/sysadmin-agent)"

# Crontab: compare against managed source of truth
echo "-- Crontab --"
"$REPO_ROOT/scripts/cron/install-crontab.sh" --check 2>&1 || true

# Caddy sites: verify expected sites exist
echo "-- Caddy sites --"
EXPECTED_SITES="adguard default home-assistant unifi _auth"
for site in $EXPECTED_SITES; do
  f="/etc/caddy/sites/${site}.caddy"
  if [ -f "$f" ]; then
    echo "  ✅ $site.caddy"
  else
    echo "  ❌ MISSING: $site.caddy"
  fi
done

# networkd-dispatcher: verify DNS hook is installed and executable
echo "-- networkd-dispatcher --"
HOOK="/etc/networkd-dispatcher/routable.d/50-dns-update"
if [ -x "$HOOK" ]; then
  echo "  ✅ 50-dns-update installed and executable"
else
  echo "  ❌ 50-dns-update missing or not executable"
fi

# Netplan: verify static IP config exists
echo "-- Netplan --"
if [ -f /etc/netplan/50-cloud-init.yaml ]; then
  if sudo grep -q '192.168.2.32' /etc/netplan/50-cloud-init.yaml 2>/dev/null; then
    echo "  ✅ Static IP 192.168.2.32 in netplan config"
  else
    echo "  ⚠️  /etc/netplan/50-cloud-init.yaml exists but 192.168.2.32 not found"
  fi
else
  echo "  ❌ /etc/netplan/50-cloud-init.yaml missing"
fi

# Systemd managed units: verify expected units are active
echo "-- Managed systemd units --"
EXPECTED_UNITS="caddy adguardhome uos-webrtc-fix"
for unit in $EXPECTED_UNITS; do
  status=$(systemctl is-active "$unit" 2>/dev/null || echo "missing")
  if [ "$status" = "active" ]; then
    echo "  ✅ $unit: active"
  else
    echo "  ⚠️  $unit: $status"
  fi
done

# Cron last-run freshness: check that daily tasks produced recent logs
echo "-- Cron freshness --"
LOG_DIR="$REPO_ROOT/local/logs"
YESTERDAY=$(date -d "yesterday" +%Y%m%d)
TODAY=$(date +%Y%m%d)
# Health check should have run today or yesterday
if ls "$LOG_DIR"/cron-${TODAY}-06*.log "$LOG_DIR"/cron-${YESTERDAY}-06*.log 2>/dev/null | head -1 | grep -q .; then
  echo "  ✅ Health check log found (today or yesterday)"
else
  echo "  ⚠️  No recent health check log — cron may not be running"
fi
# btrfs snapshot should be recent
SNAP_LOG="$LOG_DIR/btrfs-snapshot.log"
if [ -f "$SNAP_LOG" ]; then
  SNAP_AGE=$(( ( $(date +%s) - $(stat -c %Y "$SNAP_LOG") ) / 86400 ))
  if [ "$SNAP_AGE" -le 1 ]; then
    echo "  ✅ btrfs-snapshot.log updated within last day"
  else
    echo "  ⚠️  btrfs-snapshot.log is ${SNAP_AGE} days old"
  fi
else
  echo "  ⚠️  No btrfs-snapshot.log found"
fi

echo "=== SECURITY ==="
last -5 --time-format iso
grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 || true
```

## Output

Summarize as a structured report. Flag anything abnormal with ⚠️.
No swap is intentional on this machine — do NOT flag it as an issue.
If any critical issue is found, recommend immediate action.
If CONFIG DRIFT shows any ❌ or ⚠️, highlight it prominently and suggest remediation.
