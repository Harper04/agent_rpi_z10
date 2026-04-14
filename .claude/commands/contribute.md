---
name: contribute
description: Propose a shared improvement back to the template repo
argument-hint: "[description]"
user-invocable: true
---

# Contribute Improvements to Template

Scan this machine for shared improvements and push them upstream so all machines
benefit. This is a PROACTIVE skill — it doesn't just diff, it hunts for candidates.

## Step 1 — Fetch upstream and scan

```bash
git fetch upstream
```

Run ALL of these scans to find contribution candidates:

### 1a. Content changes in shared files
```bash
git diff --name-only upstream/main...HEAD -- .claude/ scripts/ docs/ templates/ CLAUDE.md .gitignore setup.sh
```

### 1b. Permission/mode changes (often missed!)
```bash
git diff upstream/main...HEAD --diff-filter=T -- .claude/ scripts/ docs/ templates/
git diff upstream/main...HEAD --stat -- scripts/  # look for "mode change" lines
```

### 1c. New files that should be shared
Look for files that were added in shared directories but don't exist upstream:
```bash
git diff upstream/main...HEAD --diff-filter=A --name-only -- .claude/ scripts/ docs/ templates/
```

### 1d. Deleted/renamed files
```bash
git diff upstream/main...HEAD --diff-filter=DR --name-only -- .claude/ scripts/ docs/ templates/
```

### 1e. Uncommitted shared changes
```bash
git status --short -- .claude/ scripts/ docs/ templates/ CLAUDE.md
```

## Step 2 — Categorize and group

For each changed file, determine:
- **Type**: bug fix, new feature, docs improvement, permission fix, new recipe, new convention
- **Scope**: which component (agent name, script name, etc.)
- **Universal?**: Would ALL machines benefit? If machine-specific, skip it.

Group related changes into logical PRs. Examples:
- All permission fixes → one PR
- One recipe → one PR  
- Related agent improvements → one PR

**Red flags — do NOT contribute:**
- Files in `local/` (machine-specific)
- Hardcoded hostnames, IPs, domains (should use placeholders)
- Secrets or tokens (run the secret scanner)
- Changes that only make sense for this machine's setup

> **Safety net:** The pre-push hook (`scripts/hooks/pre-push-no-local-upstream.sh`)
> blocks any push to upstream containing `local/` files. If the hook rejects a push,
> review the branch with `git diff --name-only upstream/main..HEAD -- local/` and
> remove local/ files before retrying.

## Step 3 — Review each candidate

For each group, show the operator:
1. Files included and a brief diff summary
2. Why it's universal
3. Proposed PR title and description

If running via Telegram, present all candidates in one message and ask which to proceed with.
If the user said "/contribute" with no specific request, present ALL candidates.

## Step 4 — Create PRs

For each approved group:

1. Create a branch from the current main (which already has the changes):
   ```bash
   git checkout -b contribute/<slug>
   ```

2. Push to upstream:
   ```bash
   git push upstream contribute/<slug>
   ```

3. Create a PR with `gh pr create`:
   ```bash
   gh pr create --repo <upstream-repo> --base main --head contribute/<slug> \
     --title "<type>: <description>" \
     --body "## Summary\n<bullets>\n\n## Files\n<list>"
   ```

4. Auto-merge (we own both repos):
   ```bash
   gh pr merge <number> --repo <upstream-repo> --merge
   ```

5. Return to main:
   ```bash
   git checkout main
   ```

## Step 5 — Verify clean

After all PRs are merged, verify nothing remains:
```bash
git fetch upstream
git diff upstream/main...HEAD --name-only -- .claude/ scripts/ docs/ templates/ CLAUDE.md
```

If empty → report "upstream fully in sync."
If not → report remaining diffs and why they weren't contributed.

## Step 6 — Scan for promotable local content

After shared diffs are clean, scan local/ for content worth promoting:

### Promote to templates/local/ (Tier 1)
Local source code that's generic enough for all machines.

**New files** — exist in local/ but not in templates/local/:
```bash
diff -rq local/ templates/local/ 2>/dev/null | grep "Only in local"
```

**Diverged files** — exist in both but local/ has improvements the template lacks:
```bash
# Find files that differ between local/ and templates/local/
# Excludes: .env, logs/, changelog, CLAUDE.local.md, .template-versions
diff -rq local/ templates/local/ 2>/dev/null | grep "^Files" | grep "differ" \
  | grep -v '.env\|logs/\|changelog\|CLAUDE.local\|.template-versions'
```

For each diverged file, check whether the local version has **universal improvements**
(new features, bug fixes, better UX) vs. **machine-specific customization** (hardcoded
hostnames, IPs, paths). Universal improvements should be synced back to the template.

**For both new and diverged files:**
1. Sanitize: replace hostnames/IPs with placeholders (e.g., `TODO-HOSTNAME`)
2. Copy to `templates/local/`
3. Include in the contribution PR
4. The propose-upstream script will accept `templates/local/` files (they're shared)

### Promote to docs/examples/ (Tier 2)
Local app docs that are well-written and could help other machines:
```bash
ls local/docs/apps/
```

If a local app doc is thorough and follows the template:
1. Sanitize: replace real hostnames, IPs, usernames, domains with `<placeholder>`
2. Copy to `docs/examples/apps/`
3. Include in the contribution PR

### NEVER promote
- `local/.env` (secrets)
- `local/CLAUDE.local.md` (machine identity)
- `local/docs/changelog.md` (machine history)
- `local/.template-versions` (machine tracking)
- Files with hardcoded secrets, tokens, or credentials

## What to contribute vs. keep local

| Contribute (shared)                    | Keep local                          |
|----------------------------------------|-------------------------------------|
| Better agent procedures                | Machine IPs, hostnames              |
| New safety rules in hooks              | local/agents/ overrides             |
| New universally useful skills/recipes  | local/docs/ content                 |
| Bug fixes in shared scripts            | Secrets, credentials                |
| Template improvements                  | Machine-specific config             |
| File permission fixes                  | Machine-specific conventions        |
| New conventions (docs/conventions.md)  | local/docs/conventions.md entries   |
| Improved command/skill definitions     | One-off workarounds                 |

## Secret scanning

Before pushing, scan all files for leaked secrets:
```
sk-ant-       (Anthropic API keys)
ghp_          (GitHub PATs classic)
github_pat_   (GitHub PATs fine-grained)
bot\d+:       (Telegram bot tokens)
AKIA          (AWS access key IDs)
```

If found, STOP and warn the operator. Never push secrets upstream.
