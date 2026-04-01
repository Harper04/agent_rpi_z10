---
name: sync
description: Pull shared improvements from the template repo
argument-hint: "[--dry-run]"
user-invocable: true
---

# Sync from Template

Pull shared updates (agents, skills, hooks, scripts) from the upstream template.

## Workflow

1. **Preview:** `./scripts/git/sync-upstream.sh --dry-run`
2. **Show operator** what would change, get confirmation.
3. **Apply:** `./scripts/git/sync-upstream.sh`
4. **Verify:** `/status`
5. **Document** in `local/docs/changelog.md`
6. **Push:** `git push origin main`
