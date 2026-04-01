#!/usr/bin/env bash
# btrfs-snapshot.sh — Nightly read-only btrfs snapshot with configurable retention
#
# Called directly from cron (NOT via cron-runner.sh / Claude).
# Exits 0 silently if the root filesystem is not btrfs.
#
# Env overrides (set in local/.env or cron environment):
#   BTRFS_SNAPSHOT_DIR          Directory to store snapshots  (default: /.snapshots)
#   BTRFS_SNAPSHOT_RETAIN_DAYS  Days to keep snapshots        (default: 30)
#
# Cron example:
#   0 2 * * *  /home/tom/sysadmin-agent/scripts/cron/btrfs-snapshot.sh

set -euo pipefail

# shellcheck source=../lib/common.sh
source "$(cd "$(dirname "$0")" && pwd)/../lib/common.sh" && common_init "$0"

LOG_FILE="${LOG_DIR}/btrfs-snapshot.log"

SNAPSHOT_DIR="${BTRFS_SNAPSHOT_DIR:-/.snapshots}"
RETAIN_DAYS="${BTRFS_SNAPSHOT_RETAIN_DAYS:-30}"

# ── Load env (Telegram credentials, overrides) ───────────────────────────────
safe_source

log()    { echo "[$(stamp)] $1" | tee -a "$LOG_FILE"; }

# ── btrfs detection ───────────────────────────────────────────────────────────
if ! findmnt -t btrfs / -n >/dev/null 2>&1; then
    log "Root filesystem is not btrfs — skipping."
    exit 0
fi

log "=== btrfs snapshot run start ==="

DATE="$(date -I)"
SNAPSHOT_NAME="root-${DATE}"
SNAPSHOT_PATH="${SNAPSHOT_DIR}/${SNAPSHOT_NAME}"

# Create snapshot directory if it doesn't exist
if [[ ! -d "$SNAPSHOT_DIR" ]]; then
    log "Creating snapshot directory: ${SNAPSHOT_DIR}"
    mkdir -p "$SNAPSHOT_DIR"
fi

# ── Create today's snapshot (idempotent) ─────────────────────────────────────
if [[ -d "$SNAPSHOT_PATH" ]]; then
    log "Snapshot ${SNAPSHOT_NAME} already exists — skipping creation."
else
    log "Creating snapshot: ${SNAPSHOT_PATH}"
    if btrfs subvolume snapshot -r / "$SNAPSHOT_PATH" >>"$LOG_FILE" 2>&1; then
        log "Snapshot created successfully: ${SNAPSHOT_NAME}"
    else
        log "ERROR: Failed to create snapshot ${SNAPSHOT_PATH}"
        telegram_send "❌ *btrfs snapshot FAILED* on \`${HOSTNAME_SHORT}\`\nCould not create \`${SNAPSHOT_NAME}\`\nCheck: \`${LOG_FILE}\`"
        exit 1
    fi
fi

# ── Prune snapshots older than RETAIN_DAYS ───────────────────────────────────
CUTOFF="$(date -d "-${RETAIN_DAYS} days" -I)"
log "Pruning snapshots older than ${RETAIN_DAYS} days (cutoff: ${CUTOFF})..."

# Collect all managed snapshots (root-YYYY-MM-DD), sorted oldest-first
mapfile -d '' ALL_SNAPSHOTS < <(
    find "$SNAPSHOT_DIR" -maxdepth 1 -name 'root-????-??-??' -type d -print0 2>/dev/null \
    | sort -z
)
TOTAL="${#ALL_SNAPSHOTS[@]}"

PRUNED=0
for snapshot_path in "${ALL_SNAPSHOTS[@]}"; do
    snapshot_name="$(basename "$snapshot_path")"
    snap_date="${snapshot_name#root-}"

    # Safety guard: never leave zero snapshots
    REMAINING=$(( TOTAL - PRUNED ))
    if (( REMAINING <= 1 )); then
        log "Safety guard: only ${REMAINING} snapshot(s) left — stopping prune."
        break
    fi

    if [[ "$snap_date" < "$CUTOFF" ]]; then
        log "Deleting expired snapshot: ${snapshot_name}"
        if btrfs subvolume delete "$snapshot_path" >>"$LOG_FILE" 2>&1; then
            PRUNED=$(( PRUNED + 1 ))
        else
            log "WARNING: Failed to delete ${snapshot_path}"
            telegram_send "⚠️ *btrfs prune warning* on \`${HOSTNAME_SHORT}\`\nFailed to delete \`${snapshot_name}\`\nCheck: \`${LOG_FILE}\`"
        fi
    fi
done

log "Pruned ${PRUNED} snapshot(s). ${SNAPSHOT_DIR} now contains $(( TOTAL - PRUNED )) snapshot(s)."
log "=== btrfs snapshot run complete ==="
