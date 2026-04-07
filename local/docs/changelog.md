# Changelog

> Append-only log of all changes made to this system by the sysadmin agent.
> Newest entries at the top.

---

## 2026-04-07 14:36 — orchestrator

**Action:** Install dashboard (Bun/TypeScript)
**Reason:** System visibility, service discovery, DNS panel, ZeroTier panel
**Files changed:**
- `/etc/systemd/system/strandstr-pi-dashboard.service` — created
- `/etc/sudoers.d/dashboard-agent-restart` — agent restart permission
- `local/.env` — added DASHBOARD_PORT, DASHBOARD_SUBTITLE, DNS_RECORD_FILTERS
- `local/docs/apps/dashboard.md` — created
- `local/CLAUDE.local.md` — updated
**Verification:** `curl http://localhost:3100/api/health` → 200; `https://s85.local.tiny-systems.eu/` → 200
**Upstream proposed:** no

---

## 2026-04-07 14:27 — orchestrator

**Action:** Install Caddy v2.11.2 with caddy-security + caddy-dns/route53 plugins
**Reason:** Reverse proxy + TLS + SSO auth portal for all web services
**Files changed:**
- `/usr/bin/caddy` — custom binary installed
- `/etc/caddy/Caddyfile` — global config, ZT-primary auth portal
- `/etc/caddy/env` — secrets (AWS, JWT, admin creds) mode 600
- `/etc/caddy/sites/_auth.caddy` — auth portal at auth.s85.zt.tiny-systems.eu
- `/etc/caddy/sites/default-zt.caddy` — dashboard behind auth on ZT
- `/etc/caddy/sites/default-local.caddy` — dashboard open on LAN
- `/etc/caddy/static/index.html` — fallback landing page
- `local/docs/apps/caddy.md` — app doc created
- `local/CLAUDE.local.md` — updated
**Verification:** All 3 Let's Encrypt production certs obtained; service active
**Upstream proposed:** no

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
