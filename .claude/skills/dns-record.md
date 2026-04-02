---
name: dns-record
description: Manage DNS records in AWS Route53 via local record files. Add, remove, list, diff, and sync records.
argument-hint: "<action> [fqdn] [type] [value]"
user-invocable: true
---

# DNS Record Management Skill

Manage DNS records declaratively. Records are defined as files in `local/dns/records/`,
then synced to AWS Route53 via `scripts/dns/dns-sync.sh`.

## File Format

Each file in `local/dns/records/` is named after the FQDN (e.g. `app.example.com`).
Content is zone-file style, one record per line:

```
A     178.104.28.233
AAAA  2a01:4f8::1
MX    10 mail.example.com
# ttl=600
```

## Actions

### Add a record

1. Determine the record file path:
   ```bash
   RECORD_FILE="local/dns/records/${FQDN}"
   ```

2. If file exists, check if this type+value already present:
   ```bash
   grep -qi "^${TYPE}[[:space:]]" "$RECORD_FILE" 2>/dev/null
   ```

3. Append or create the record line:
   ```bash
   echo "${TYPE}    ${VALUE}" >> "$RECORD_FILE"
   ```
   For multi-value (e.g. adding a second A record), just append another line.
   For replacing (e.g. changing the A record), remove the old line first.

4. Ask the operator: "Record file updated. Run sync now?" If yes:
   ```bash
   scripts/dns/dns-sync.sh --dry-run
   ```
   Show output. If changes look correct, ask to apply:
   ```bash
   scripts/dns/dns-sync.sh
   ```

5. Commit:
   ```bash
   git add "local/dns/records/${FQDN}"
   git commit -m "dns(${FQDN}): add ${TYPE} record"
   ```

### Remove a record

1. If a specific type is given, remove matching lines from the file:
   ```bash
   sed -i "/^${TYPE}[[:space:]]/Id" "local/dns/records/${FQDN}"
   ```
   If file is now empty, delete it.

2. If no type given, delete the entire file:
   ```bash
   rm "local/dns/records/${FQDN}"
   ```

3. Run sync (dry-run first, then apply after confirmation).

4. Commit:
   ```bash
   git add -A "local/dns/records/"
   git commit -m "dns(${FQDN}): remove ${TYPE:-all} record(s)"
   ```

### List records

```bash
echo "=== DNS Records ==="
for f in local/dns/records/*; do
  [ -f "$f" ] || continue
  echo ""
  echo "--- $(basename "$f") ---"
  cat "$f"
done
```

### Diff (dry-run)

```bash
scripts/dns/dns-sync.sh --dry-run
```

Show the output to the operator. No changes are applied.

### Sync

```bash
# Always show plan first
scripts/dns/dns-sync.sh --dry-run
```

Show the plan. Ask: "Apply these changes?" If confirmed:

```bash
scripts/dns/dns-sync.sh
```

## Prerequisites Check

Before any sync operation, verify:

```bash
# AWS CLI installed?
command -v aws &>/dev/null || echo "ERROR: aws CLI not installed"

# Credentials configured?
source local/.env
[ -n "${AWS_ACCESS_KEY_ID:-}" ] || echo "ERROR: AWS_ACCESS_KEY_ID not set in local/.env"

# Config exists?
[ -f local/dns/dns.conf ] || echo "ERROR: local/dns/dns.conf not found"
```

## Documentation

After adding or removing records, update the app doc if it exists:
- `local/docs/apps/route53-dns.md` — update the managed records table

After any sync, append to changelog:
```markdown
## YYYY-MM-DD HH:MM — orchestrator

**Action:** DNS record <action>: <fqdn> <type> <value>
**Reason:** <operator request or context>
**Files changed:** local/dns/records/<fqdn>
**Verification:** dns-sync.sh completed successfully
**Upstream proposed:** no
```
