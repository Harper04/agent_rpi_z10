---
name: sync
description: Pull shared improvements from the template repo
argument-hint: "[--dry-run]"
user-invocable: true
---

# Sync from Template

Pull shared updates (agents, skills, hooks, scripts) from the upstream template,
then apply any template changes to local/ files.

## How it works

Sync has two phases:

### Phase 1 — Shared files (automatic)
Merges upstream/main into your branch. This updates `.claude/`, `scripts/`, `docs/`,
`templates/`, `CLAUDE.md`, etc. Standard git merge — no magic.

### Phase 2 — Template → local/ sync
Compares `templates/local/` against `local/` to detect upstream improvements:

- **Unmodified local files** → auto-updated (safe — you didn't change them)
- **New template files** → copied to local/ (new features)
- **Customized local files** → flagged for review (template changed AND you changed it)
- **Unchanged templates** → skipped

Tracked via `local/.template-versions` — records which template version each local
file was seeded/synced from.

## Workflow

1. **Preview:**
   ```bash
   ./scripts/git/sync-upstream.sh --dry-run
   ```
   Shows incoming commits, changed shared files, and template sync status.

2. **Show operator** what would change, get confirmation.

3. **Apply:**
   ```bash
   ./scripts/git/sync-upstream.sh
   ```
   This runs both Phase 1 (merge) and Phase 2 (template sync) automatically.

4. **Handle review files** — if any local files were flagged for review:
   ```bash
   diff local/<file> templates/local/<file>
   # Decide: keep local version, accept template, or merge manually
   cp templates/local/<file> local/<file>  # to accept template version
   ```

5. **Verify:** `/status`

6. **Commit + push:**
   ```bash
   git add -A && git commit -m "chore: sync with upstream template $(date -I)"
   git push origin main
   ```

7. **Document** in `local/docs/changelog.md`

## The 3-tier model

```
Tier 1: templates/local/     ← Seeds (upstream template repo)
  Generic, placeholder files. setup.sh copies these to local/.
  Bug fixes and enhancements here are synced to machines via /sync.

Tier 2: docs/examples/       ← Reference docs (upstream template repo)
  Sanitized real-world examples from actual machines.
  Agents reference these when filling in local docs.
  NOT copied to local/ — just for guidance.

Tier 3: local/               ← Live data (machine repo only, NEVER upstream)
  Actual deployed configs with real hostnames, IPs, secrets references.
  Customized per machine. Tracked against Tier 1 via .template-versions.
```
