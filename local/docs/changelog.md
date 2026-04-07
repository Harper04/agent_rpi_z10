# Changelog

> Append-only log of all changes made to this system by the sysadmin agent.
> Newest entries at the top.

---

## 2026-04-07 14:18 — orchestrator

**Action:** Route53 DNS setup — install aws-cli, create s85 ZT and LAN records
**Reason:** Prerequisite for Caddy (DNS-01 TLS) and dashboard
**Files changed:**
- `local/dns/dns.conf` — OWNER_TAG=s85, IP_RECORD_MAP configured
- `local/dns/records/s85.zt.tiny-systems.eu` — A → 192.168.195.217
- `local/dns/records/s85.local.tiny-systems.eu` — A → 192.168.2.93
- Route53: created 4 records (A + wildcard CNAME for both .zt and .local)
- `local/CLAUDE.local.md` — ZT/LAN domains added
**Verification:** All 4 records INSYNC in Route53; dig @8.8.8.8 confirms resolution
**Upstream proposed:** no

---

## 2026-04-07 14:08 — orchestrator

**Action:** Install ZeroTier, join network `8286ac0e476c329b` (Core)
**Reason:** Operator requested overlay VPN for machine-to-machine connectivity
**Files changed:**
- `/etc/apt/sources.list.d/zerotier.list` — ZeroTier apt repo added
- `local/docs/apps/zerotier.md` — app doc created
- `local/CLAUDE.local.md` — app table + ports updated
**Verification:** `zerotier-cli listnetworks` shows status OK, ZT IP 192.168.195.217/24; eth0 remains at 192.168.2.93
**Upstream proposed:** no

---

## 2026-04-07 11:27 — orchestrator

**Action:** Full system inventory
**Reason:** Initial `/inventory` run — populated all TODO placeholders with real system data
**Files changed:**
- `local/docs/system/overview.md` — hardware, OS, disk, access details
- `local/docs/system/packages.md` — key packages + full list
- `local/docs/system/services.md` — running services + timers
- `local/docs/system/network.md` — interfaces, ports, routing, DNS
- `local/CLAUDE.local.md` — purpose, OS details, installed apps, ports
**Verification:** All docs reviewed against live system output; no failed services detected
**Upstream proposed:** no

---

## YYYY-MM-DD HH:MM — orchestrator

**Action:** Repository initialized
**Reason:** Initial setup of sysadmin-agent for this machine
**Files changed:** All initial files created
**Verification:** Repository structure validated
