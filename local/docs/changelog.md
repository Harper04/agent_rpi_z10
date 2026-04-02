# Changelog

> Append-only log of all changes made to this system by the sysadmin agent.
> Newest entries at the top.

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
