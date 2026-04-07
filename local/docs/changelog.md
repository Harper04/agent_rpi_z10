# Changelog

> Append-only log of all changes made to this system by the sysadmin agent.
> Newest entries at the top.

---

## 2026-04-07 18:04 — docker

**Action:** Install AdGuard Home as Podman container (Quadlet systemd unit)

**Why:** Network-wide DNS ad blocking for LAN and ZeroTier clients.

**What changed:**
- Created `/opt/adguardhome/{conf,work}/` data directories
- Pre-seeded `/opt/adguardhome/conf/AdGuardHome.yaml` (DNS bound to 192.168.2.93 and 192.168.195.217, port 53; web UI on 0.0.0.0:3000; Cloudflare+Google DoH upstreams; AdGuard+AdAway filter lists)
- Created `/etc/containers/systemd/adguardhome.container` Quadlet unit (host networking, AutoUpdate=registry)
- Started `adguardhome.service` via `systemctl start` (Quadlet generated units are transient, not enable-able)
- Created `/etc/caddy/sites/adguard.caddy` — LAN domain open, ZT domain auth-gated via `default_policy`
- Created Route53 CNAME records: `adguard.s85.local.tiny-systems.eu` and `adguard.s85.zt.tiny-systems.eu`
- Reloaded Caddy; TLS certs being issued via DNS-01 challenge
- Created `local/docs/apps/adguard-home.md`
- Updated `local/CLAUDE.local.md` (apps table + custom ports)

**Image pulled:** `docker.io/adguard/adguardhome:latest` (v0.107.73)
**DNS responds on:** 192.168.2.93:53 and 192.168.195.217:53
**libvirt dnsmasq on 192.168.122.1:53 unaffected**

---

## 2026-04-07 17:33 — caddy

**Action:** Configure Caddy reverse proxy and DNS records for UniFi OS Server

**Changes:**
- Created `/etc/caddy/sites/unifi.caddy` with multi-domain block for `unifi.s85.local.tiny-systems.eu` and `unifi.s85.zt.tiny-systems.eu`
- Applied UniFi-specific proxy requirements: TLS upstream with `tls_insecure_skip_verify`, HTTP/1.1 forced via `alpn http/1.1` + `versions 1.1`, Origin and Location header rewrites
- No `authorize with default_policy` on either domain — UniFi has its own login
- Created Route53 CNAME records: `unifi.s85.zt.tiny-systems.eu` and `unifi.s85.local.tiny-systems.eu` (both CNAMEs to their parent domain, TTL 300)
- Wrote local DNS record files to `local/dns/records/`
- Let's Encrypt TLS certs obtained via DNS-01/Route53 for both domains
- Caddy reloaded zero-downtime; both domains return HTTP 200

**Reason:** Expose UniFi OS Server (running on port 11443) via Caddy with proper TLS termination and header handling

---

## 2026-04-07 17:24 — docker

**Action:** Install UniFi OS Server v5.0.6 (uosserver) with Ubuntu 25.10 compatibility fixes
**Reason:** UniFi network device controller; operator requested installation
**Files changed:**
- `/etc/systemd/system/uosserver.service` — added `Delegate=yes` (required for podman on kernel 6.17)
- `/etc/systemd/system/uosserver.service.d/10-cgroup-fix.conf` — created; sets `CONTAINERS_CONF_OVERRIDE`
- `/etc/uosserver/containers-override.conf` — created; forces `cgroup_manager = "cgroupfs"`
- `/home/uosserver/.config/containers/containers.conf` — installer-created; helper_binaries_dir
- `/etc/systemd/system/uos-webrtc-fix.service` — installed WebRTC fix (dummy br0 in container ns)
- `local/systemd/uos-webrtc-fix.service` — repo copy with real REPO_PATH substituted
- `local/docs/apps/docker/unifi-os-server.md` — created
- `local/CLAUDE.local.md` — app table + ports updated
**Verification:**
- `sudo uosserver status` → container Up (healthy), all services running ✓
- `ss -tlnp | grep 11443` → LISTEN ✓
- `uos-webrtc-fix.service` → active (exited), br0 @ 192.168.2.93 created in container ns ✓
- Host IP 192.168.2.93 on br0 unchanged ✓
**Issues encountered:**
- Initial installer failed: crun scope creation error under cgroup v2 / kernel 6.17
- Container exited with code 255: cgroupfs read-only inside container without Delegate+cgroupfs fix
- Container deleted before service start: manually recreated with matching podman args
**Upstream proposed:** no

---

## 2026-04-07 18:50 — orchestrator

**Action:** Enable SSH addon for Home Assistant, configure trusted_proxies, verify Caddy proxy
**Reason:** Enable SSH access to HAOS; fix reverse proxy HTTP 400 errors from missing trusted_proxies
**Files changed:**
- `/homeassistant/configuration.yaml` (inside HAOS VM) — trusted_proxies: 192.168.2.93 added
- SSH addon options via Supervisor API — authorized_keys set, port 22/tcp mapped to 22222
- `local/docs/apps/home-assistant.md` — SSH section added, gotchas documented
**Verification:**
- `ssh -i ~/.ssh/id_ed25519_ha -p 22222 root@192.168.2.182` → connects ✓
- `curl https://ha.s85.zt.tiny-systems.eu/` → HTTP 200 ✓
- `curl https://ha.s85.local.tiny-systems.eu/` → HTTP 200 ✓
- HA core restarted via SSH; came back up in <60s ✓
**Upstream proposed:** no

---

## 2026-04-07 14:45 — orchestrator

**Action:** Install Home Assistant OS 17.2 via KVM + bridge network
**Reason:** Home automation platform; KVM provides full HAOS with Supervisor/Add-ons
**Files changed:**
- `/etc/netplan/99-static-eth0.yaml` — migrated from eth0 static to br0 bridge (host stays at .93)
- `/var/lib/libvirt/images/haos_generic-aarch64-17.2.qcow2` — VM disk
- `/etc/caddy/sites/home-assistant.caddy` — ZT + LAN reverse proxy, no auth
- `local/dns/records/ha.s85.zt.tiny-systems.eu` — CNAME created
- `local/dns/records/ha.s85.local.tiny-systems.eu` — CNAME created
- `local/docs/apps/home-assistant.md` — created
- `local/docs/system/network.md` — updated for br0
- `local/docs/conventions.md` — bridge state annotated
- `local/CLAUDE.local.md` — updated
**Verification:** br0 @ 192.168.2.93 ✓; HAOS VM @ 192.168.2.182 responding HTTP 302 ✓
**Upstream proposed:** no

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
