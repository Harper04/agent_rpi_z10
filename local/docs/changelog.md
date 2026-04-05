# Changelog

> Append-only log of all changes made to this system by the sysadmin agent.
> Newest entries at the top.

---

## 2026-04-05 14:33 — orchestrator

**Action:** Added ZeroTier domain for dashboard
**Reason:** `z10.zt.tiny-systems.eu` resolved to ZT IP but had no Caddy site block — connection refused from ZT network
**Fix:** Added `z10.zt.tiny-systems.eu` to dashboard site block in `/etc/caddy/sites/default.caddy` (comma-separated, same pattern as HA and UniFi)
**Files changed:** /etc/caddy/sites/default.caddy
**Verification:** TLS cert obtained via DNS-01, HTTPS 200 confirmed

---

## 2026-04-05 14:27 — orchestrator

**Action:** Synced upstream template (9 commits)
**Details:**
- Contribute skill: detect diverged template files in Tier 1 scan
- Dashboard UI: compact DNS tree, clickable domains, A+AAAA merge
- README rewrite in English
- Added *.bak.* to .gitignore
- Fixed UniFi proxy recipe (WebSocket + HTTP/1.1)
- Updated local/docs/apps/_template.md with new reverse proxy section
**Files changed:** .claude/commands/contribute.md, .gitignore, README.md, templates/local/dashboard/*, local/dashboard/*, local/docs/apps/_template.md

---

## 2026-04-05 13:44 — orchestrator

**Action:** Fixed UniFi Caddy reverse proxy (WebSocket + redirects)

- **Root cause:** UniFi rejects WebSocket upgrades with 500 when Origin header doesn't match `127.0.0.1`; HTTP/2 doesn't support traditional WebSocket upgrade (101)
- **Fix:** Added `header_up Origin https://127.0.0.1:11443`, forced HTTP/1.1 on both sides via `alpn http/1.1` and `versions 1.1`, changed upstream to `127.0.0.1`, added Location header rewrites
- **Config:** `/etc/caddy/sites/unifi.caddy`
- **Docs:** Updated `local/docs/apps/unifi-os-server.md` and `docs/recipes/unifi-os-server.md`

## 2026-04-05 12:04 — orchestrator

**Action:** Added ZeroTier API credentials to dashboard

- Added `ZEROTIER_API_KEY` and `ZEROTIER_NETWORK_ID` to `local/.env`
- Restarted dashboard — ZeroTier members now visible (7 members)

## 2026-04-05 12:00 — orchestrator

**Action:** Restored local/ files deleted by upstream merge

- Commit `65c54ce` (auto-merge of upstream/main) propagated deletion of local/ from template repo
- Restored all 39 files from pre-merge state (commit `3148dc0`)

## 2026-04-05 11:08 — orchestrator

**Action:** Onboarded UniFi OS behind Caddy reverse proxy
**Reason:** UniFi had no DNS/Caddy integration, was not visible on dashboard
**Details:**
- Created DNS CNAMEs: unifi.z10.local.tiny-systems.eu + unifi.z10.zt.tiny-systems.eu
- Created Caddy site block with HTTPS upstream + tls_insecure_skip_verify (self-signed cert)
- No post-proxy config needed — UniFi accepts all forwarded headers without restriction
- TLS certs obtained via DNS-01 for both domains
- UniFi now visible on system dashboard
**Files changed:** local/dns/records/unifi.z10.{local,zt}.tiny-systems.eu (created), /etc/caddy/sites/unifi.caddy (created), local/docs/apps/unifi-os-server.md, local/docs/apps/binary/caddy.md
**Verification:** HTTPS 200 on LAN and ZT domains, dashboard shows UniFi OS tile
**Upstream proposed:** no

---

## 2026-04-05 10:02 — orchestrator

**Action:** Reduced Home Assistant VM RAM from 4 GB to 2.5 GB
**Reason:** Host RAM nearly full (346 MB available). HAOS on-demand allocation still consumed most of the 4 GB ceiling.
**Details:**
- Set VM max memory to 2621440 KiB (2.5 GB) via virsh setmaxmem/setmem --config
- Required full VM power cycle (destroy + start) — HAOS lacks balloon driver and ignores ACPI shutdown
- Freed ~1.5 GB host RAM (available went from 346 MB to 1.8 GB)
**Files changed:** VM XML config (libvirt), local/docs/apps/home-assistant.md
**Verification:** All 3 HA access paths return HTTP 200
**Upstream proposed:** no

---

## 2026-04-05 09:32 — orchestrator

**Action:** Added ZeroTier access for Home Assistant
**Reason:** Enable remote HA access via ZeroTier network
**Details:**
- Created DNS CNAME: ha.z10.zt.tiny-systems.eu → z10.zt.tiny-systems.eu
- Updated Caddy site block to accept both LAN and ZT domains
- Added explicit `tls { dns route53 }` block for cert issuance on ZT domain
- Let's Encrypt cert obtained via DNS-01 challenge
**Files changed:** local/dns/records/ha.z10.zt.tiny-systems.eu (created), /etc/caddy/sites/home-assistant.caddy (updated), local/docs/apps/home-assistant.md, local/docs/apps/binary/caddy.md
**Verification:** HTTPS 200 on both ZT IP (192.168.195.108) and LAN IP (192.168.2.32)
**Upstream proposed:** no

---

## 2026-04-05 09:30 — orchestrator

**Action:** Onboarded Home Assistant behind Caddy reverse proxy
**Reason:** HA had no DNS/Caddy integration, was not visible on system dashboard
**Details:**
- Created DNS CNAME: ha.z10.local.tiny-systems.eu → z10.local.tiny-systems.eu
- Created Caddy site block: /etc/caddy/sites/home-assistant.caddy (no auth, HA has own)
- Configured HA trusted_proxies via SSH addon (core_ssh) for X-Forwarded-For support
- Installed core_ssh addon in HA for config file management (port disabled after use)
- Generated SSH key pair on host for HA access (~/.ssh/id_ed25519)
- Saved HA API token to local/.env
**Files changed:** local/dns/records/ha.z10.local.tiny-systems.eu (created), /etc/caddy/sites/home-assistant.caddy (created), local/docs/apps/home-assistant.md, local/docs/apps/binary/caddy.md, local/.env
**Verification:** https://ha.z10.local.tiny-systems.eu/ returns HTTP 200
**Upstream proposed:** no

---

## 2026-04-05 06:00 — orchestrator

**Action:** Switched DNS from wildcard to explicit per-app records
**Reason:** Operator wants explicit DNS records for each Caddy virtual hostname; wildcards kept only for TLS cert issuance
**Details:**
- Created explicit CNAME records: auth.z10.local.tiny-systems.eu, adguard.z10.local.tiny-systems.eu
- Deleted wildcard CNAME record: *.z10.local.tiny-systems.eu
- Fixed TTL mismatch bug in dns-sync.sh DELETE for owner TXT records (used DEFAULT_TTL instead of actual Route53 TTL)
- Updated caddy-onboard-app skill: always create explicit DNS record, never rely on wildcard
- Updated dns-record skill: added "Explicit Records Only" policy section
**Files changed:** local/dns/records/auth.z10.local.tiny-systems.eu (created), local/dns/records/adguard.z10.local.tiny-systems.eu (created), local/dns/records/*.z10.local.tiny-systems.eu (deleted), scripts/dns/dns-sync.sh (bugfix), .claude/skills/caddy-onboard-app.md, .claude/skills/dns-record.md
**Verification:** dns-sync.sh dry-run shows 0 changes — Route53 in sync
**Upstream proposed:** yes (dns-sync.sh bugfix, skill updates)

---

## 2026-04-04 15:56 — orchestrator

**Action:** Added dynamic DNS update on IP change
**Reason:** DNS records in Route53 were stale after Pi relocation (192.168.2.171 → 192.168.2.32)
**Details:**
- Created `scripts/dns/dns-ip-update.sh` — compares interface IPs to record files, updates + syncs on change
- Created `scripts/dns/networkd-dns-update.sh` — networkd-dispatcher hook, fires on interface routable state
- Installed hook to `/etc/networkd-dispatcher/routable.d/50-dns-update`
- Added `IP_RECORD_MAP` to `local/dns/dns.conf` mapping br0 and zt+ to their FQDNs
- Fixed stale record: z10.local.tiny-systems.eu A 192.168.2.171 → 192.168.2.32
- Route53 updated successfully (change C063814024QCP6D6VOGIZ)
**Files changed:** scripts/dns/dns-ip-update.sh (created), scripts/dns/networkd-dns-update.sh (created), local/dns/dns.conf (updated), local/dns/records/z10.local.tiny-systems.eu (updated), local/docs/apps/route53-dns.md (updated)
**Verification:** dry-run detected stale IP, live run updated Route53

---

## 2026-04-04 14:28 — orchestrator

**Action:** Fixed WebRTC remote access for UOS on generic ARM64 hardware
**Reason:** Remote access via Ubiquiti cloud/app was broken — WebRTC ICE gathering produced zero candidates
**Root cause:** pasta networking exposes host's `/proc/net/route` to the container, which lists `br0` as default route. unifi-core tells the WebRTC addon `allowed_interfaces: ['br0']`. But the container namespace only has `eth0` (pasta TAP) — no `br0` exists → ICE gathering completes instantly with zero candidates → all remote connections time out.
**Fix:** Create a dummy `br0` interface (type dummy) inside the container's network namespace with the host's br0 IP. The WebRTC addon discovers br0, binds to its IP, and traffic routes through pasta's eth0 TAP device. ICE candidates are generated, TURN relay connections succeed.
**Persistence:** `uos-webrtc-fix.service` (systemd oneshot, enabled) runs `scripts/hooks/uos-webrtc-fix.sh` after `uosserver.service` starts. The script waits for the container's conmon→init PID, then creates the dummy br0 via `nsenter`.
**Files changed:** scripts/hooks/uos-webrtc-fix.sh (created), local/systemd/uos-webrtc-fix.service (created), /etc/systemd/system/uos-webrtc-fix.service (installed), local/docs/apps/unifi-os-server.md (updated known issues + changelog)
**Verification:** WebRTC logs show ICE candidates generated, TURN relay connected in 1.17s, user confirmed remote access working

---

## 2026-04-04 13:57 — orchestrator

**Action:** UOS purge & reinstall after Pi relocation; investigated remote access failure
**Reason:** Pi moved to new location, DHCP IP changed from .171 to .32. Ubiquiti cloud/app remote access not working.
**Details:**
- Purged and reinstalled UOS v5.0.6 (fresh setup wizard completed)
- Investigated WebRTC ICE failure: pasta networking prevents WebRTC addon from generating ICE candidates (interface name mismatch: addon expects `br0`, pasta creates `eth0`)
- Attempted host networking (port conflicts), pasta interface rename (broke network translation) — neither worked
- Reverted to working pasta setup. Remote access remains broken on generic ARM64 hardware.
- Recommended ZeroTier as workaround for remote access
**Files changed:** local/docs/apps/unifi-os-server.md (updated UOS UUID, IP, known issues), local/CLAUDE.local.md (updated IP)
**Verification:** `uosserver status` → healthy, Web UI HTTP 200 on https://192.168.2.32:11443/

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
