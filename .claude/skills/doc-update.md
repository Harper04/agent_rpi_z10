---
name: doc-update
description: Update system documentation after any change. Invoke after every operation that modifies system state.
user-invocable: true
---

# Documentation Update Skill

After completing any system modification, execute this documentation workflow:

## Steps

1. **Identify scope** — What changed? Which app/system component?

2. **Update the relevant doc file:**
   - System-level change → `local/docs/system/<component>.md`
   - App-level change → `local/docs/apps/<app>.md`
   - New app installed → Copy `docs/apps/_template.md` to `local/docs/apps/<app>.md` and fill it

3. **Update package list if packages changed:**
   ```bash
   dpkg --list | grep ^ii | awk '{print $2, $3}' > /tmp/pkg-list.txt
   ```
   Compare with `local/docs/system/packages.md` and update differences.

4. **Append to changelog:**
   File: `local/docs/changelog.md`
   ```markdown
   ## YYYY-MM-DD HH:MM — <agent-name>

   **Action:** <concise description>
   **Reason:** <why this was done>
   **Files changed:** <system files modified>
   **Docs updated:** <doc files updated>
   **Verification:** <how we confirmed success>
   **Upstream proposed:** no
   ```

5. **Git commit:**
   ```bash
   git add local/docs/
   git commit -m "docs(<scope>): <what changed>"
   ```

6. **If the change affects network/ports**, also update `local/docs/system/network.md`.

7. **Evaluate for upstream contribution:**
   - Did you improve a shared agent definition while working? → Commit the shared
     file separately and note `Upstream proposed: yes` in the changelog.
   - Machine-specific findings stay in `local/` only.
