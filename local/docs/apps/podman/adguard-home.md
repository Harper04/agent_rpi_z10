# AdGuard Home

> **Method:** Podman (Quadlet)
> **Status:** Installed (setup wizard pending)
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
| AGH ver   | TBD (after setup wizard)                                   |

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
| 53   | tcp+udp  | 178.104.28.233  | DNS (after wizard)   |
| 3000 | tcp      | 0.0.0.0         | Web UI (temporary)   |

## Firewall (ufw)

| Rule       | Status  |
|------------|---------|
| 22/tcp     | allowed (SSH) |
| 53/tcp+udp | allowed (DNS) |
| 3000/tcp   | allowed (temporary, remove after Caddy) |

## Security Notes

- **allowed_clients** must be configured after setup wizard to prevent open resolver
- **rate limiting** (30 qps) to be set in AGH config
- **refuse_any: true** to prevent DNS amplification
- Port 3000 is publicly accessible until Caddy + caddy-security is deployed

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

- [ ] Complete setup wizard at http://178.104.28.233:3000
- [ ] Configure DNS bind to 178.104.28.233 (not 0.0.0.0)
- [ ] Set allowed_clients whitelist
- [ ] Enable rate limiting
- [ ] Add filter lists
- [ ] Set up Caddy reverse proxy with caddy-security
- [ ] Remove ufw rule for port 3000 after Caddy
- [ ] Configure downstream sync for home AGH instances
- [ ] Add to backup schedule
- [ ] Enable DoH/DoT (optional)
