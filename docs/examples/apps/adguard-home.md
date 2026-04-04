# AdGuard Home

> **Method:** Podman (Quadlet)
> **Status:** Running
> **Agent:** orchestrator
> **Last verified:** YYYY-MM-DD
> **Recipe:** `docs/recipes/adguard-home.md`

## Overview

Network-wide DNS ad/tracker blocker running as an internet-facing upstream server.
Home network AGH instances sync configuration from this instance.

## Container Image

| Field     | Value                                  |
|-----------|----------------------------------------|
| Image     | `docker.io/adguard/adguardhome`        |
| Tag       | `latest`                               |
| Digest    | `sha256:<record after pull>`           |
| Pulled    | YYYY-MM-DD                             |

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

| Port | Protocol | Binding            | Purpose              |
|------|----------|--------------------|----------------------|
| 53   | tcp+udp  | <public-ip>        | DNS                  |
| 3000 | tcp      | 127.0.0.1          | Web UI (behind Caddy)|

## Caddy Integration

- Reverse proxy: `<app>.<hostname>.tiny-systems.eu` → `localhost:3000`
- Auth: `default_policy` (SSO via Caddy auth portal)
- Site file: `/etc/caddy/sites/adguard.caddy` (with `@dashboard true` annotation)

## Configuration Changes

| Date | Change | Reason |
|------|--------|--------|
| YYYY-MM-DD | Initial install | Fresh deployment |
