---
name: contribute
description: Propose a shared improvement back to the template repo
argument-hint: "[--file <path>] \"description\""
user-invocable: true
---

# Contribute Improvement to Template

Propose improvements to shared agents, skills, hooks, or scripts back to the
template repo so all machines benefit.

## How It Works

You own both the template repo (upstream) and this machine repo (origin).
No fork or PR needed — just push a branch to upstream and merge it there.

## Workflow

1. **Detect changes** in shared files:
   ```bash
   git diff --name-only upstream/main...HEAD -- .claude/ scripts/ docs/ templates/ CLAUDE.md
   ```

2. **Review** — confirm changes are universal, not machine-specific.

3. **Run the script:**
   ```bash
   ./scripts/git/propose-upstream.sh "description of improvement"
   # or for specific files:
   ./scripts/git/propose-upstream.sh --file .claude/agents/caddy.md "improved TLS handling"
   # or export as patch:
   ./scripts/git/propose-upstream.sh --patch "safety improvements"
   ```

4. **Push and merge** (after operator confirmation):
   ```bash
   git push upstream propose/<branch>
   git checkout main
   # On template repo: merge the branch
   ```

## What to contribute vs. keep local

| Contribute (shared)                    | Keep local                          |
|----------------------------------------|-------------------------------------|
| Better agent procedures                | Machine IPs, hostnames              |
| New safety rules in hooks              | local/agents/ overrides             |
| New universally useful skills          | local/docs/ content                 |
| Bug fixes in shared scripts            | Secrets, credentials                |
| Template improvements                  | Machine-specific config             |
