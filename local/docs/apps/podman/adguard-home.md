# AdGuard Home

> **Method:** Podman (Quadlet)
> **Status:** Running (hardened, allowed_clients pending)
> **Agent:** orchestrator
> **Last verified:** 2026-04-02
> **Recipe:** `docs/recipes/adguard-home.md`

## Overview

Network-wide DNS ad/tracker blocker running as an internet-facing upstream server.
Home network AGH instances sync configuration from this instance.

## Container Image

| Field     | Value                                                      |
|-----------|------------------------------------------------------------|
| Image     | `docker.io/adguard/adguardhome`                            |
| Tag       | `latest`                                                   |
| Digest    | `sha256:7fbf01d73ecb7a32d2d9e6cef8bf88e64bd787889ca80a1e8bce30cd4c084442` |
| Pulled    | 2026-04-02                                                 |
| AGH ver   | schema_version 33                                          |

## Runtime

| Component       | Value                                            |
|-----------------|--------------------------------------------------|
| Systemd unit    | `adguardhome.service` (Quadlet-generated)        |
| Quadlet file    | `/etc/containers/systemd/adguardhome.container`  |
| Network mode    | `--net=host`                                     |
| Config dir      | `/opt/adguardhome/conf/`                         |
| Work dir        | `/opt/adguardhome/work/`                         |
| Image log       | `/opt/adguardhome/image-history.log`             |
| Auto-update     | `registry` (via `podman auto-update`)            |

## Ports

| Port | Protocol | Binding         | Purpose              |
|------|----------|-----------------|----------------------|
| 53   | tcp+udp  | 178.104.28.233  | DNS                  |
| 3000 | tcp      | 127.0.0.1       | Web UI (behind Caddy)|

## Firewall (ufw)

| Rule       | Status  |
|------------|---------|
| 22/tcp     | allowed (SSH) |
| 53/tcp+udp | allowed (DNS) |
| 80/tcp     | allowed (Caddy HTTP redirect) |
| 443/tcp    | allowed (Caddy HTTPS)         |

## Security Notes

- **allowed_clients: []** (empty = open resolver!) — MUST add home IPs before production use
- **ratelimit: 20** qps per client subnet — active
- **refuse_any: true** — active, prevents DNS amplification
- **DNSSEC: enabled** — validates upstream responses
- **safebrowsing: enabled** — blocks known malicious domains
- **cache: 10 MB, min TTL 300s** — reduces upstream queries
- **upstream: Quad9 DoH** (`dns10.quad9.net`) — encrypted, malware-blocking
- Web UI on 127.0.0.1:3000, proxied via Caddy at https://adguard.mini-core.tiny-systems.eu/ (auth required)

## Update Procedure

```bash
# Check for updates
podman auto-update --dry-run

# Apply update
podman auto-update

# Or manual with logging — see recipe
```

## Backup

- `/opt/adguardhome/conf/` — YAML config + filter caches
- `/opt/adguardhome/image-history.log` — version trail

## TODO

- [x] Complete setup wizard
- [x] Configure DNS bind to 178.104.28.233
- [x] Enable rate limiting (20 qps)
- [x] Enable DNSSEC, safebrowsing, refuse_any
- [x] Increase cache (10 MB, 300s min TTL)
- [ ] **Set allowed_clients whitelist (⚠️ currently open resolver!)**
- [ ] Set up Caddy reverse proxy with caddy-security
- [ ] Remove ufw rule for port 80 after Caddy
- [ ] Add more filter lists (OISD, etc.)
- [ ] Configure downstream sync for home AGH instances
- [ ] Add to backup schedule
- [ ] Enable DoH/DoT (optional)
