# Changelog

> Append-only log of all changes made to this system by the sysadmin agent.
> Newest entries at the top.

---

## 2026-04-02 13:45 — orchestrator

**Action:** Installed Route53 DNS management service
- Installed aws-cli v2.34.22 via snap
- Created `local/dns/dns.conf` with owner tag `ziegeleiweg-pi`
- Created `local/dns/records/` directory
- Added AWS credentials to `local/.env`
- Verified access to hosted zone `tiny-systems.eu.` (ZUS1MBK3O5V24)

---

## 2026-04-02 10:35 — orchestrator

**Action:** Installed Home Assistant OS 17.1 as KVM VM
**Reason:** Requested by operator via Telegram — standard supported HAOS installation
**Details:**
- Installed KVM stack (QEMU 10.1.0, libvirt 11.6.0, UEFI firmware)
- Created network bridge br0 (eth0 enslaved, host IP now 192.168.2.173)
- Downloaded haos_generic-aarch64-17.1.qcow2, resized to 32 GB
- Created VM with on-demand memory allocation (4 GB max, lazy pages)
- VM IP: 192.168.2.174, Web UI: http://192.168.2.174:8123
- mDNS discovery confirmed working on br0
**Files changed:** local/docs/apps/home-assistant.md (created), local/CLAUDE.local.md (updated), /etc/netplan/50-cloud-init.yaml (bridge)
**Verification:** curl → HTTP 302, tcpdump confirms mDNS queries from VM

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
