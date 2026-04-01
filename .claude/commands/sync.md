---
name: sync
description: Pull shared improvements from the upstream template
argument-hint: "[--dry-run]"
user-invocable: true
---

# Sync from Upstream Template

Pull in shared improvements (agents, skills, hooks, scripts) from the upstream
template repository.

## Workflow

1. **Preview changes:**
   ```bash
   ./scripts/git/sync-upstream.sh --dry-run
   ```

2. **Show the operator** what would change and get confirmation.

3. **Apply:**
   ```bash
   ./scripts/git/sync-upstream.sh
   ```

4. **Post-sync checks:**
   - Verify agents still work: `/status`
   - Check if new agents/skills were added that need local config
   - Update `local/CLAUDE.local.md` if needed

5. **Document:**
   Append to `local/docs/changelog.md`:
   ```markdown
   ## YYYY-MM-DD HH:MM — orchestrator

   **Action:** Synced with upstream template
   **Reason:** Pull shared improvements
   **Upstream commits:** <count> new commits
   **Verification:** /status check passed
   ```
