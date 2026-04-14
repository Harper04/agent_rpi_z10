# AdGuard Home

> **Status:** Running
> **Last verified:** 2026-04-07
> **Managed by agent:** `docker`
> **Installation method:** `podman` (Quadlet systemd unit)
> **Recipe:** manual

## Overview

AdGuard Home is a network-wide DNS ad blocker and privacy filter. It runs as a Podman
container managed by systemd via a Quadlet unit file. It intercepts DNS queries for all
LAN clients pointed at this machine and blocks ads, trackers, and malicious domains using
curated filter lists.

## Installation

Deployed as a rootful Podman container via Quadlet, with host networking so it can bind
to port 53 on specific LAN IPs.

```bash
sudo mkdir -p /opt/adguardhome/{conf,work}
# pre-seeded /opt/adguardhome/conf/AdGuardHome.yaml
# wrote /etc/containers/systemd/adguardhome.container
sudo systemctl daemon-reload
sudo systemctl start adguardhome.service
```

## Version

| Component     | Version       | Source                                    |
|---------------|---------------|-------------------------------------------|
| AdGuard Home  | `v0.107.73`   | `docker.io/adguard/adguardhome:latest`    |

Auto-update is enabled via `AutoUpdate=registry` in the Quadlet unit.

## Configuration

### Config files

| File                                      | Purpose                          |
|-------------------------------------------|----------------------------------|
| `/opt/adguardhome/conf/AdGuardHome.yaml`  | Main AdGuard Home configuration  |
| `/opt/adguardhome/work/`                  | Runtime data (filter lists, logs, query log DB) |
| `/etc/containers/systemd/adguardhome.container` | Quadlet systemd unit       |

### Key settings

- **DNS bind hosts:** `192.168.2.93` and `192.168.195.217` — LAN and ZeroTier IPs only. Intentionally NOT `0.0.0.0` to avoid conflicting with libvirt dnsmasq on `192.168.122.1:53`.
- **Web UI port:** `3000` (accessed via Caddy reverse proxy, not exposed directly).
- **Upstream DNS:** Cloudflare DoH and Google DoH (load-balanced).
- **Bootstrap DNS:** 9.9.9.10, 149.112.112.10 (used to resolve DoH upstream hostnames).
- **Filter lists:** AdGuard DNS filter + AdAway Default Blocklist.
- **DHCP:** disabled (handled by router).
- **DNSSEC:** disabled (can be enabled if needed).
- **Query log retention:** 720h (30 days).
- **Statistics retention:** 720h (30 days).

### Admin credentials

- Default username: `admin`
- Default password: `adguard` (bcrypt hash pre-seeded)
- **Change immediately via web UI:** https://adguard.s85.local.tiny-systems.eu/#settings

To change password: Settings -> Users -> Edit -> set new password.

## Network

| Port   | Protocol | Purpose              | Exposed to                             |
|--------|----------|----------------------|----------------------------------------|
| 53     | UDP/TCP  | DNS                  | 192.168.2.93 and 192.168.195.217 only  |
| 3000   | TCP      | Web UI (HTTP)        | localhost only (proxied by Caddy)      |

**Router DNS config:** Point your router's primary DNS to `192.168.2.93` to enable
network-wide ad blocking for all LAN clients.

## Data & Storage

| Path                              | Purpose               | Backed up? |
|-----------------------------------|-----------------------|------------|
| `/opt/adguardhome/conf/`          | Configuration         | No (can be re-seeded) |
| `/opt/adguardhome/work/`          | Filter lists, query log, statistics DB | No |

## Dependencies

- Depends on: `network-online.target`, br0 interface with 192.168.2.93 assigned
- Depends on: Caddy (for web UI access)
- Depended on by: LAN clients (once router DNS is pointed at this host)
- Note: libvirt dnsmasq on `192.168.122.1:53` is independent — no conflict

## Health Check

```bash
# Service status
sudo systemctl status adguardhome.service

# DNS responding
dig @192.168.2.93 example.com +short +time=3

# Check port listeners
ss -tlnp | grep ':53 ' | grep -v '127.0.0'

# Container status
sudo podman ps --filter name=adguardhome

# Container logs
sudo podman logs adguardhome --tail=30
```

## Common Operations

### Restart

```bash
sudo systemctl restart adguardhome.service
```

### View logs

```bash
sudo journalctl -u adguardhome.service --since "1 hour ago"
sudo podman logs adguardhome --tail=50
```

### Update

Podman auto-update handles this via the `AutoUpdate=registry` Quadlet directive.
To manually update:

```bash
sudo podman pull docker.io/adguard/adguardhome:latest
sudo systemctl restart adguardhome.service
```

### Access web UI

- LAN: https://adguard.s85.local.tiny-systems.eu/
- ZeroTier (auth-gated): https://adguard.s85.zt.tiny-systems.eu/

## Reverse Proxy (Caddy)

| Key        | Value                                                  |
|------------|--------------------------------------------------------|
| Site block | `/etc/caddy/sites/adguard.caddy`                       |
| LAN domain | `https://adguard.s85.local.tiny-systems.eu/`           |
| ZT domain  | `https://adguard.s85.zt.tiny-systems.eu/` (auth-gated) |
| Auth       | LAN: OFF, ZT: ON (with `default_policy`)               |
| Upstream   | `http://localhost:3000`                                |

### Post-proxy config

AdGuard Home does not require trusted_proxies configuration for the web UI — Caddy
strips and re-adds forwarding headers transparently for this use case.

## Known Issues & Gotchas

- The Quadlet-generated systemd unit (`/run/systemd/generator/adguardhome.service`) is
  transient and cannot be `systemctl enable`'d. It auto-starts because the `.container`
  file is in `/etc/containers/systemd/`. Reboots are safe — Quadlet regenerates the unit.
- libvirt dnsmasq runs on `192.168.122.1:53`. AdGuard Home is intentionally NOT bound
  to 0.0.0.0 to avoid conflict. Never change `bind_hosts` to include `192.168.122.1`.
- `caddy validate` reports a JWT key error for the ZT auth block — this is a known
  false positive during dry-run when `JWT_SHARED_KEY` env var is absent. Caddy reloads
  correctly when the service runs with the full environment.

## Changelog (app-specific)

| Date       | Change               | Agent    |
|------------|----------------------|----------|
| 2026-04-07 | Initial installation | docker   |
