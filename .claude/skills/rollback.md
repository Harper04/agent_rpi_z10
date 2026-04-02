---
name: rollback
description: Roll back a configuration change by restoring from .bak files or btrfs snapshots
user-invocable: true
argument-hint: "[file-or-service]"
---

# Rollback

Restore a previous configuration state and verify the affected service recovers.

## Procedure

### 1. Identify What to Roll Back

If the operator specifies a file:
```bash
# Find .bak files for the specified config
ls -lt <file>.bak.* 2>/dev/null
```

If the operator specifies a service:
```bash
# Check changed-files log for recent modifications to that service's config
grep "<service>" local/logs/changed-files.log 2>/dev/null | tail -10
```

If neither is specified:
```bash
# Show recent changes from the tracking log
tail -20 local/logs/changed-files.log 2>/dev/null
```

Present the options and ask the operator which change to revert.

### 2. Verify Backup Exists

```bash
# For config file rollback
ls -la <file>.bak.* 2>/dev/null
diff <file> <file>.bak.<latest-date>

# For btrfs snapshot rollback (more drastic)
ls ${BTRFS_SNAPSHOT_DIR:-/.snapshots}/ 2>/dev/null
```

Show the diff between current and backup. Ask for confirmation.

### 3. Restore

```bash
# Back up the CURRENT (broken) version first
cp <file> <file>.bak.$(date -I)-pre-rollback

# Restore from backup
cp <file>.bak.<selected-date> <file>
```

### 4. Reload Service

Identify the affected service and reload it:
```bash
# Validate config if possible (e.g., caddy validate, nginx -t)
# Then reload
systemctl reload <service> 2>/dev/null || systemctl restart <service>
systemctl status <service>
```

### 5. Verify

```bash
# Check service is running
systemctl is-active <service>

# Check for errors in journal
journalctl -u <service> --since "1 min ago" --no-pager
```

### 6. Document

Append to `local/docs/changelog.md`:
```markdown
## YYYY-MM-DD HH:MM — orchestrator

**Action:** Rolled back <file> to version from <date>
**Reason:** <operator's reason>
**Files changed:** <file> restored from <file>.bak.<date>
**Verification:** Service <service> reloaded and running
```
