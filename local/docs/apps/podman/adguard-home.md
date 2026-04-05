# AdGuard Home

> **Status:** Running
> **Last verified:** 2026-04-04
> **Managed by agent:** `orchestrator`
> **Installation method:** Podman Quadlet (--net=host)
> **Recipe:** `docs/recipes/adguard-home.md`

## Overview

Network-wide DNS ad/tracker blocker. LAN deployment on ziegeleiweg-pi,
serving DNS on 192.168.2.32:53. Web UI behind Caddy at
adguard.z10.local.tiny-systems.eu.

## Installation

Installed per `docs/recipes/adguard-home.md`, adapted for LAN:
- DNS bind: 192.168.2.32 (not 0.0.0.0)
- Web UI: 192.168.2.32:7080 (proxied via Caddy)
- No allowed_clients whitelist (LAN only)

## Version

| Component       | Version  | Source                         |
|-----------------|----------|--------------------------------|
| AdGuard Home    | latest   | docker.io/adguard/adguardhome  |
| Image digest    | sha256:e51007... | See /opt/adguardhome/image-history.log |

## Configuration

| Key               | Value                                       |
|-------------------|---------------------------------------------|
| DNS bind          | `192.168.2.32:53`                           |
| Web UI bind       | `192.168.2.32:7080`                         |
| Admin user        | `tomjaster`                                 |
| Caddy domain      | `adguard.z10.local.tiny-systems.eu`         |
| Quadlet unit      | `/etc/containers/systemd/adguardhome.container` |
| Config            | `/opt/adguardhome/conf/AdGuardHome.yaml`    |
| Work dir          | `/opt/adguardhome/work/`                    |

## Network

| Port   | Protocol | Purpose          | Exposed to   |
|--------|----------|------------------|--------------|
| 53     | TCP/UDP  | DNS              | LAN (br0)    |
| 7080   | TCP      | Web UI           | localhost (via Caddy) |

## Health Check

```bash
systemctl is-active adguardhome.service
dig @192.168.2.32 example.com +short +time=2
curl -sf -o /dev/null -w "%{http_code}" http://192.168.2.32:7080/
```

## Common Operations

### Update image
```bash
sudo podman auto-update --dry-run
sudo podman auto-update
```

## Changelog

| Date       | Change                              | Agent        |
|------------|-------------------------------------|--------------|
| 2026-04-04 | Initial install via Podman Quadlet  | orchestrator |
