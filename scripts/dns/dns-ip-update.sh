#!/usr/bin/env bash
# dns-ip-update.sh — Update DNS record files when interface IPs change.
#
# Reads IP_RECORD_MAP from local/dns/dns.conf to know which interface
# maps to which FQDN record file. Compares current IP to the record
# file and updates + syncs to Route53 if changed.
#
# Designed to be called by:
#   - networkd-dispatcher (routable.d/) on interface state changes
#   - cron as a periodic safety net
#   - manually for testing
#
# Usage:
#   dns-ip-update.sh                    # check all mapped interfaces
#   dns-ip-update.sh --iface br0        # check only br0
#   dns-ip-update.sh --dry-run          # show changes without applying

set -eo pipefail

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/../lib/common.sh" && common_init "$0"

safe_source "$ENV_FILE"

DNS_CONF="$REPO_ROOT/local/dns/dns.conf"
RECORD_DIR="$REPO_ROOT/local/dns/records"
DNS_SYNC="$REPO_ROOT/scripts/dns/dns-sync.sh"
DRY_RUN=false
FILTER_IFACE=""

[[ -f "$DNS_CONF" ]] && safe_source "$DNS_CONF"

# ── CLI args ─────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     DRY_RUN=true; shift ;;
    --iface|-i)    FILTER_IFACE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: dns-ip-update.sh [--dry-run] [--iface <name>]"
      exit 0 ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
done

# ── Parse IP_RECORD_MAP ──────────────────────────────────────────────────────
# Format in dns.conf:  IP_RECORD_MAP="br0=z10.local.tiny-systems.eu zt+=z10.zt.tiny-systems.eu"
# Each entry: <interface_pattern>=<fqdn>
# interface_pattern: exact name (br0) or glob (zt+ matches zt*)

if [[ -z "${IP_RECORD_MAP:-}" ]]; then
  echo "No IP_RECORD_MAP configured in $DNS_CONF — nothing to do."
  exit 0
fi

log() { echo "$(stamp) [dns-ip-update] $*"; }

CHANGED=0

for mapping in $IP_RECORD_MAP; do
  iface_pattern="${mapping%%=*}"
  fqdn="${mapping##*=}"

  if [[ -z "$iface_pattern" || -z "$fqdn" ]]; then
    log "WARNING: malformed mapping '$mapping', skipping"
    continue
  fi

  # Resolve interface pattern to actual interface name
  # Patterns ending with + are treated as prefix matches (like zt+ → zt*)
  if [[ "$iface_pattern" == *+ ]]; then
    prefix="${iface_pattern%+}"
    iface=$(ip -o link show | awk -F': ' '{print $2}' | grep "^${prefix}" | head -1)
  else
    iface="$iface_pattern"
  fi

  if [[ -z "$iface" ]]; then
    log "Interface pattern '$iface_pattern' has no match, skipping"
    continue
  fi

  # Apply filter if specified
  if [[ -n "$FILTER_IFACE" && "$iface" != "$FILTER_IFACE" ]]; then
    continue
  fi

  # Get current IP
  current_ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[0-9.]+' | head -1)
  if [[ -z "$current_ip" ]]; then
    log "No IPv4 on $iface, skipping $fqdn"
    continue
  fi

  # Get recorded IP
  record_file="$RECORD_DIR/$fqdn"
  recorded_ip=""
  if [[ -f "$record_file" ]]; then
    recorded_ip=$(grep -oP '^A\s+\K[0-9.]+' "$record_file" | head -1)
  fi

  if [[ "$current_ip" == "$recorded_ip" ]]; then
    log "$iface ($fqdn): $current_ip — no change"
    continue
  fi

  log "$iface ($fqdn): $recorded_ip → $current_ip"
  CHANGED=$((CHANGED + 1))

  if $DRY_RUN; then
    log "  (dry-run, not writing)"
    continue
  fi

  # Update record file
  echo "A $current_ip" > "$record_file"
  log "  Updated $record_file"
done

# ── Sync to Route53 if anything changed ──────────────────────────────────────
if [[ $CHANGED -gt 0 && "$DRY_RUN" == "false" ]]; then
  log "Running dns-sync.sh to push changes to Route53..."
  if "$DNS_SYNC" 2>&1 | while IFS= read -r line; do log "  $line"; done; then
    log "DNS sync complete."
    telegram_send "🌐 *DNS updated* ($HOSTNAME_SHORT): $CHANGED record(s) changed"
  else
    log "ERROR: dns-sync.sh failed"
    telegram_send "⚠️ *DNS update failed* ($HOSTNAME_SHORT): dns-sync.sh exited non-zero"
  fi
elif [[ $CHANGED -eq 0 ]]; then
  log "All records up to date."
fi
