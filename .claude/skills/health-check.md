---
name: health-check
description: Comprehensive system health check. Run on demand or scheduled.
user-invocable: true
---

# System Health Check

Run a full system health assessment and report results.

## Checks

```bash
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || echo "$HOME/sysadmin-agent")"
DRIFT_CONF="$REPO_ROOT/local/health-drift.conf"
[ -f "$DRIFT_CONF" ] && source "$DRIFT_CONF"

echo "=== IDENTITY ==="
hostname -f && date -Is && uname -r

echo "=== UPTIME & LOAD ==="
uptime

echo "=== MEMORY ==="
free -h
# If NO_SWAP_OK=true in health-drift.conf, no swap is intentional — do not flag it.

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

# Crontab: compare against managed source of truth
echo "-- Crontab --"
if [ -x "$REPO_ROOT/scripts/cron/install-crontab.sh" ]; then
  "$REPO_ROOT/scripts/cron/install-crontab.sh" --check 2>&1 || true
else
  echo "  ℹ️  install-crontab.sh not found — skipping"
fi

# Caddy sites: verify expected sites exist (from health-drift.conf)
echo "-- Caddy sites --"
if [ -n "${EXPECTED_CADDY_SITES:-}" ]; then
  for site in $EXPECTED_CADDY_SITES; do
    f="/etc/caddy/sites/${site}.caddy"
    if [ -f "$f" ]; then
      echo "  ✅ $site.caddy"
    else
      echo "  ❌ MISSING: $site.caddy"
    fi
  done
else
  echo "  ℹ️  No expected sites configured in health-drift.conf"
fi

# networkd-dispatcher hooks (from health-drift.conf)
echo "-- networkd-dispatcher --"
if [ -n "${EXPECTED_DISPATCHER_HOOKS:-}" ]; then
  for hook in $EXPECTED_DISPATCHER_HOOKS; do
    if [ -x "$hook" ]; then
      echo "  ✅ $(basename "$hook") installed and executable"
    else
      echo "  ❌ $(basename "$hook") missing or not executable"
    fi
  done
else
  echo "  ℹ️  No expected hooks configured"
fi

# Netplan: verify static IP (from health-drift.conf)
echo "-- Netplan --"
if [ -n "${EXPECTED_NETPLAN_IP:-}" ]; then
  NP_FILE="${NETPLAN_FILE:-/etc/netplan/50-cloud-init.yaml}"
  if [ -f "$NP_FILE" ]; then
    if sudo grep -q "$EXPECTED_NETPLAN_IP" "$NP_FILE" 2>/dev/null; then
      echo "  ✅ Static IP $EXPECTED_NETPLAN_IP in netplan config"
    else
      echo "  ⚠️  $NP_FILE exists but $EXPECTED_NETPLAN_IP not found"
    fi
  else
    echo "  ❌ $NP_FILE missing"
  fi
else
  echo "  ℹ️  No expected IP configured"
fi

# Systemd managed units (from health-drift.conf)
echo "-- Managed systemd units --"
if [ -n "${EXPECTED_SYSTEMD_UNITS:-}" ]; then
  for unit in $EXPECTED_SYSTEMD_UNITS; do
    status=$(systemctl is-active "$unit" 2>/dev/null || echo "missing")
    if [ "$status" = "active" ]; then
      echo "  ✅ $unit: active"
    else
      echo "  ⚠️  $unit: $status"
    fi
  done
else
  echo "  ℹ️  No expected units configured"
fi

# Cron last-run freshness
echo "-- Cron freshness --"
LOG_DIR="$REPO_ROOT/local/logs"
YESTERDAY=$(date -d "yesterday" +%Y%m%d)
TODAY=$(date +%Y%m%d)
if ls "$LOG_DIR"/cron-${TODAY}-06*.log "$LOG_DIR"/cron-${YESTERDAY}-06*.log 2>/dev/null | head -1 | grep -q .; then
  echo "  ✅ Health check log found (today or yesterday)"
else
  echo "  ⚠️  No recent health check log — cron may not be running"
fi
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
If `NO_SWAP_OK=true` in health-drift.conf, do NOT flag missing swap as an issue.
If any critical issue is found, recommend immediate action.
If CONFIG DRIFT shows any ❌ or ⚠️, highlight it prominently and suggest remediation.
