---
name: backup-verify
description: Verify backup integrity — check btrfs snapshots exist, test rsync checksums, validate Docker volume archives
user_invocable: true
---

# Backup Verification

Run a comprehensive check of all configured backup mechanisms on this machine.

## Procedure

### 1. btrfs Snapshots

```bash
# Check if root is btrfs
findmnt -t btrfs / -n 2>/dev/null

# List recent snapshots
SNAPSHOT_DIR="${BTRFS_SNAPSHOT_DIR:-/.snapshots}"
ls -lt "$SNAPSHOT_DIR" 2>/dev/null | head -10

# Verify newest snapshot is from today or yesterday
ls "$SNAPSHOT_DIR" | sort -r | head -1
```

**Pass criteria:**
- At least 1 snapshot exists
- Newest snapshot is no older than 48 hours
- Snapshot count matches expected retention window (~30 days worth)

### 2. Snapshot Log Health

```bash
# Check snapshot log for recent errors
tail -20 local/logs/btrfs-snapshot.log 2>/dev/null
```

**Pass criteria:**
- Log shows successful run within last 24 hours
- No ERROR lines in last 7 days

### 3. rsync Backups (if configured)

If `local/docs/apps/backup.md` mentions rsync targets:

```bash
# Test connectivity to rsync target
# Verify last rsync timestamp
# Spot-check file integrity with --checksum --dry-run
```

### 4. Docker Volume Backups (if configured)

If Docker is installed and volumes exist:

```bash
# List Docker volumes
docker volume ls 2>/dev/null
# Check for recent volume backup archives
ls -lt /var/backups/docker/ 2>/dev/null | head -5
```

### 5. Report

Generate a summary report:

| Check | Status | Detail |
|-------|--------|--------|
| btrfs snapshots | PASS/FAIL | N snapshots, newest: YYYY-MM-DD |
| Snapshot log | PASS/FAIL | Last success: YYYY-MM-DD HH:MM |
| rsync | PASS/FAIL/N/A | Last sync: ... |
| Docker volumes | PASS/FAIL/N/A | N volumes backed up |

If any check fails, send a warning via the `notify` skill.

### 6. Document

Update `local/docs/apps/backup.md` with:
- Last verification date
- Results summary
- Any issues found
