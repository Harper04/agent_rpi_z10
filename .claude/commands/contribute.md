---
name: contribute
description: Propose a shared improvement back to the upstream template
argument-hint: "[--file <path>] \"description\""
user-invocable: true
---

# Contribute Improvement Upstream

Propose improvements to shared agents, skills, hooks, or scripts back to the
upstream template repository so all machines benefit.

## Workflow

1. **Identify what changed** in shared files (not in `local/`):
   ```bash
   git diff --name-only upstream/main...HEAD -- .claude/ scripts/ docs/ CLAUDE.md
   ```

2. **Review the changes** and confirm they are universal (not machine-specific).

3. **Run the proposal script:**
   ```bash
   ./scripts/git/propose-upstream.sh "description of improvement"
   ```
   Or for specific files:
   ```bash
   ./scripts/git/propose-upstream.sh --file .claude/agents/caddy.md "improved TLS handling"
   ```

4. **Show the operator** the diff and branch name for review.

5. **After confirmation,** push the branch:
   ```bash
   git push upstream <branch-name>
   git checkout main
   ```

## Safety Checks

Before proposing, verify:
- [ ] No files from `local/` are included
- [ ] No secrets, IPs, hostnames, or machine-specific paths leaked
- [ ] The improvement applies to all machines, not just this one

## What SHOULD be contributed

- Better agent procedures (improved command sequences, new gotchas)
- New or improved safety rules in hooks
- New skills that are universally useful
- Bug fixes in shared scripts
- Template improvements (docs/apps/_template.md, etc.)

## What should NOT be contributed

- Machine-specific configs, IPs, hostnames
- Local agent overrides from `local/agents/`
- Anything in `local/docs/`
- Secrets or credentials
