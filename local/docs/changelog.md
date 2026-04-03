# Changelog

> Append-only log of all changes made to this system by the sysadmin agent.
> Newest entries at the top.

---

## 2026-04-03 09:50 — caddy

**Action:** Fixed auth portal configuration — moved to `/auth/` base path, enabled admin API, fixed profile SPA navigation
**Reason:** Profile SPA sidebar links doubled the path prefix (`/profile/profile/...`); portal settings/MFA pages were inaccessible
**Files changed:**
- `/etc/caddy/Caddyfile` — added `enable admin api`, moved all portal links to `/auth/` prefix, updated auth redirect URLs
- `/etc/caddy/sites/_auth.caddy` — serve authenticate handler under `route /auth*`, root redirects to `/auth/`
- UFW: updated port 80 comment from "AdGuard Home Web UI" to "Caddy HTTP redirect"
**Verification:**
- Login flow works end-to-end (login → sandbox → portal → profile)
- Profile SPA sidebar links resolve correctly (`/auth/profile/multi-factor-authenticators/`)
- MFA/passkey management accessible via My Profile
**Upstream proposed:** no

---

## 2026-04-03 08:54 — caddy

**Action:** Installed Caddy v2.11.2 with caddy-security + route53 plugins as reverse proxy with auth portal
**Reason:** Operator request — secure web applications with SSO (passkeys), HTTPS via Route53 DNS-01
**Files changed:**
- `/usr/bin/caddy` — custom binary with plugins
- `/etc/systemd/system/caddy.service` — systemd service
- `/etc/caddy/Caddyfile` — main config with auth portal (Internet flavor)
- `/etc/caddy/env` — secrets (JWT key, AWS creds, admin user)
- `/etc/caddy/sites/_auth.caddy` — auth portal site
- `/etc/caddy/sites/default.caddy` — static landing page
- `/etc/caddy/sites/adguard.caddy` — AdGuard Home reverse proxy
- `/etc/caddy/static/index.html` — landing page
- `/opt/adguardhome/conf/AdGuardHome.yaml` — moved web UI from 0.0.0.0:80 → 127.0.0.1:3000
- `local/dns/records/*.mini-core.tiny-systems.eu` — wildcard CNAME
- UFW: opened port 443/tcp
**Verification:**
- `curl -sI https://mini-core.tiny-systems.eu/` → 302 to auth portal
- `curl -sI https://auth.mini-core.tiny-systems.eu/` → 302 to login + sets SSO cookie
- `curl -sI https://adguard.mini-core.tiny-systems.eu/` → 302 to auth portal
- TLS: Let's Encrypt E7, valid until Jul 2026, TLSv1.3
**Upstream proposed:** no (machine-specific install; recipe/agent/skills already committed to shared)

---

## 2026-04-03 06:35 — orchestrator

**Action:** Renamed hostname from `min-core` to `mini-core`, updated all references
**Reason:** `min-core` was a typo — should be `mini-core`
**Files changed:**
- `/etc/hostname` — via `hostnamectl set-hostname mini-core`
- `/etc/hosts` — `127.0.1.1 mini-core` (backup at `.bak.2026-04-03`)
- `local/CLAUDE.local.md` — all occurrences
- `local/dns/dns.conf` — `OWNER_TAG`
- `local/docs/apps/apt/route53-dns.md` — `OWNER_TAG` reference
- `docs/recipes/adguard-home.md` — architecture diagram references
**Verification:** `hostname` → `mini-core`; `grep -r min-core` → no matches remaining
**Upstream proposed:** no (machine-specific, except recipe which had machine name in example)

---

## 2026-04-03 05:10 — orchestrator

**Action:** Merged upstream (5 commits), fixed cron-runner PATH for native claude install
**Reason:** Upstream had merged PRs; cron jobs failed because cron's minimal PATH doesn't include `~/.local/bin` where claude is installed natively
**Files changed:**
- Merged upstream: `scripts/cron/btrfs-snapshot.sh`, `scripts/cron/crontab.example` (sudo fixes)
- `scripts/cron/cron-runner.sh` — added PATH expansion for `~/.local/bin`, `~/.npm-global/bin`, `/usr/local/bin`; extracts `CLAUDE_CODE_OAUTH_TOKEN` from `~/.bashrc`; fails gracefully with Telegram notification if claude not found
**Verification:** Tested PATH + token resolution in minimal `env -i` cron-like environment — both resolve correctly
**Upstream proposed:** yes (cron-runner fix is shared)

---

## 2026-04-02 19:05 — orchestrator

**Action:** Post-wizard hardening of AdGuard Home, firewall cleanup
**Reason:** Setup wizard completed by operator; applied security hardening and fixed port mismatch
**Files changed:**
- `/opt/adguardhome/conf/AdGuardHome.yaml` — cache 10MB, min TTL 300s, DNSSEC on, safebrowsing on (backup at `.bak.2026-04-02`)
- ufw: removed stale 3000/tcp rule, added 80/tcp (AGH wizard moved UI from 3000→80)
- `local/docs/apps/podman/adguard-home.md` — updated ports, security state, TODOs
- `local/CLAUDE.local.md` — updated status and ports
**Verification:** `dig @178.104.28.233 example.com` → resolves; `curl http://178.104.28.233:80/` → HTTP 302; service active
**Upstream proposed:** no (machine-specific config)

---

## 2026-04-02 18:54 — orchestrator

**Action:** Installed AdGuard Home via Podman Quadlet, enabled ufw firewall
**Reason:** Internet-facing upstream DNS server for ad/tracker blocking; home AGH instances will sync from this
**Files changed:**
- `/etc/containers/systemd/adguardhome.container` — Quadlet unit (--net=host, AutoUpdate=registry)
- `/opt/adguardhome/{conf,work}` — persistent data directories created
- `/opt/adguardhome/image-history.log` — initial digest recorded
- `docs/recipes/adguard-home.md` — new recipe (shared)
- `local/docs/apps/podman/adguard-home.md` — app doc for this machine
- `local/CLAUDE.local.md` — added adguard-home to installed apps, updated ports and notes
- ufw enabled with rules: SSH (22), DNS (53), Web UI (3000)
**Verification:** `systemctl is-active adguardhome.service` → active; `curl http://178.104.28.233:3000/` → HTTP 302 (setup wizard ready)
**Upstream proposed:** yes (recipe is in shared docs/recipes/)

---

## 2026-04-02 14:45 — orchestrator

**Action:** Fixed propose-upstream.sh — better secret detection, auto-push, agent-friendly
**Reason:** Script false-positived on setup.sh (matched variable names like `TELEGRAM_BOT_TOKEN` not actual secrets), blocked headless use with `read -rp`, didn't push or return to branch
**Files changed:**
- `scripts/git/propose-upstream.sh` — rewrote secret scanner (token patterns instead of key names), added `--yes`/`--no-push` flags, auto-push + return to branch, fixed `echo` content mangling
**Verification:** setup.sh no longer triggers false positive; real token patterns (ghp_*, AKIA*, bot*:*) are caught correctly
**Upstream proposed:** yes

---

## 2026-04-02 14:30 — orchestrator

**Action:** Fixed setup.sh to remove enabledPlugins from user settings after Telegram plugin install
**Reason:** `claude plugin install` writes `enabledPlugins` to `~/.claude/settings.json`, causing every manual `claude` session to load the Telegram plugin and compete with the systemd agent's poller
**Files changed:**
- `setup.sh` — added `jq 'del(.enabledPlugins)'` cleanup step after plugin install
- `scripts/agent/run-agent.sh` — updated comment to reference setup.sh counterpart
**Verification:** `jq 'del(.enabledPlugins)'` correctly strips the key; systemd agent uses `--settings` flag instead
**Upstream proposed:** yes (shared files)

---

## 2026-04-02 14:23 — orchestrator

**Action:** Restricted Telegram plugin to systemd agent only
**Reason:** `~/.claude/settings.json` had `enabledPlugins` with Telegram enabled at user level, causing every manual `claude` session to also poll Telegram — competing with the systemd agent
**Files changed:**
- `~/.claude/settings.json` — removed `enabledPlugins` block (plugin already passed via `--settings` flag in `run-agent.sh`)
**Verification:** `systemctl restart sysadmin-agent` — agent starts with Telegram channel; manual `claude --agent orchestrator` no longer loads the Telegram plugin
**Upstream proposed:** no (user-level config, machine-specific)

---

## 2026-04-02 14:10 — orchestrator

**Action:** Fixed headless agent startup — bypass-permissions prompt was blocking tmux/systemd launch
**Reason:** `--dangerously-skip-permissions` shows an interactive confirmation on every launch; in headless mode this blocks the agent indefinitely
**Files changed:**
- `setup.sh` — new section writes `skipDangerousModePermissionPrompt: true` to `~/.claude/settings.json`
- `scripts/agent/run-agent.sh` — added comments documenting the workaround
- `~/.claude/settings.json` — applied the setting on this machine
**Verification:** `systemctl restart sysadmin-agent` → Claude launches directly into agent mode with Telegram channel, no prompt
**Upstream proposed:** yes — PR https://github.com/Harper04/agent-sysadmin/pull/14

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
