# Changelog

> Append-only log of all changes made to this system by the sysadmin agent.
> Newest entries at the top.

---

## 2026-04-02 — orchestrator

**Action:** Merged upstream, added mini-core DNS record, fixed dns-sync.sh duplicate owner TXT bug
**Reason:** Upstream merge was stuck with conflicts; needed DNS entry for mini-core.tiny-systems.eu; script crashed on multi-record hosts due to duplicate owner TXT changes in same Route53 batch
**Files changed:**
- `scripts/dns/dns-sync.sh` — fixed duplicate `_owner` TXT record in changeset when host has multiple record types (A + AAAA)
- `local/dns/records/mini-core.tiny-systems.eu` — A + AAAA records for this machine
- `local/docs/changelog.md` — this entry
**Verification:** `dig mini-core.tiny-systems.eu A` → 178.104.28.233, `dig mini-core.tiny-systems.eu AAAA` → 2a01:4f8:1c1b:e5ef::1
**Upstream proposed:** yes (dns-sync.sh bugfix is shared)

---

## 2026-04-02 13:27 — orchestrator

**Action:** Created route53-dns service — file-based DNS record management for AWS Route53
**Reason:** Need declarative DNS management with owner tags for shared hosted zones
**Files changed:**
- `scripts/dns/dns-sync.sh` — sync engine (shared)
- `.claude/skills/dns-record.md` — agent skill for add/remove/list/diff/sync
- `.claude/commands/dns.md` — `/dns` slash command
- `docs/recipes/route53-dns.md` — installation recipe (shared)
- `local/dns/dns.conf` — machine config (owner tag, default TTL)
- `local/dns/records/` — record file directory (empty, ready)
- `local/docs/apps/apt/route53-dns.md` — app documentation
- `local/CLAUDE.local.md` — added route53-dns to installed apps
- `local/docs/system/packages.md` — added aws-cli
- Installed: `aws-cli` 2.34.22 (snap)
**Verification:** `aws --version` returns 2.34.22, script parses correctly
**Upstream proposed:** yes (shared files: script, skill, command, recipe)

---

## 2026-04-02 13:00 — orchestrator

**Action:** Installed GitHub CLI (`gh` 2.89.0) and added to setup.sh
**Reason:** Required for PR creation, issue management, and GitHub API operations
**Files changed:**
- `setup.sh` — added gh CLI install step + gh auth with PAT
- `local/docs/system/packages.md` — added gh to key packages
**Verification:** `gh --version` returns 2.89.0, `gh auth status` confirms authentication
**Upstream proposed:** yes (setup.sh is a shared file)

---

## 2026-04-02 12:52 — orchestrator

**Action:** Full system inventory
**Reason:** Initial `/inventory` run to populate all documentation for this machine
**Files changed:**
- `local/docs/system/overview.md` — hardware, OS, disk layout, users
- `local/docs/system/packages.md` — key packages, sources, held packages
- `local/docs/system/services.md` — running services, failed units, timers
- `local/docs/system/network.md` — interfaces, ports, DNS, routing
- `local/CLAUDE.local.md` — machine identity updated with full details
**Verification:** All data gathered from live system commands (hostnamectl, dpkg, systemctl, ss, ip, resolvectl)
**Upstream proposed:** no

---

## 2026-04-02 — operator

**Action:** Updated docs and setup.sh with correct repo org/name and Claude Code onboarding
**Reason:** Repo org is `harper04`, template repo is `agent-sysadmin`. Headless machines need Claude Code OAuth token setup.
**Files changed:** CLAUDE.md, setup.sh, local/docs/changelog.md
**Details:**
- All example URLs now use `harper04/agent-sysadmin` instead of `you/sysadmin-agent`
- Added Claude Code onboarding docs (OAuth token in .bashrc, .claude.json hasCompletedOnboarding)
- setup.sh now interactively prompts for CLAUDE_CODE_OAUTH_TOKEN and writes it to ~/.bashrc
- setup.sh ensures ~/.claude.json has `hasCompletedOnboarding: true`

---

## YYYY-MM-DD HH:MM — orchestrator

**Action:** Repository initialized
**Reason:** Initial setup of sysadmin-agent for this machine
**Files changed:** All initial files created
**Verification:** Repository structure validated
