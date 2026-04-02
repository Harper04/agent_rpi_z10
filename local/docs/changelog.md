# Changelog

> Append-only log of all changes made to this system by the sysadmin agent.
> Newest entries at the top.

---

## 2026-04-02 09:55 — orchestrator

**Action:** Installed UniFi OS Server 5.0.6 (Podman-based, ARM64)
**Reason:** Requested by operator via Telegram
**Details:** Installed podman 5.4.2 + slirp4netns 1.2.1, downloaded official ARM64 installer, ran installation. Container running as `uosserver` user. Web UI at https://192.168.2.171:11443/
**Files changed:** local/docs/apps/unifi-os-server.md (created), local/CLAUDE.local.md (updated)
**Verification:** `uosserver status` → running, ports 11443/8080/8443 listening

---

## 2026-04-02 09:35 — orchestrator

**Action:** Installed ZeroTier v1.16.1, joined network 8286ac0e476c329b
**Reason:** Requested by operator via Telegram
**Files changed:** local/docs/apps/zerotier.md (created), local/CLAUDE.local.md (updated)
**Verification:** `zerotier-cli status` → ONLINE, network status ACCESS_DENIED (awaiting authorization)

---

## YYYY-MM-DD HH:MM — orchestrator

**Action:** Repository initialized
**Reason:** Initial setup of sysadmin-agent for this machine
**Files changed:** All initial files created
**Verification:** Repository structure validated
