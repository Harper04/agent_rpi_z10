---
name: "caddy"
method: apt
version: "latest"
ports: [80, 443]
dependencies: [curl, gpg]
reverse-proxy: false
domain: ""
data-paths: ["/var/lib/caddy", "/etc/caddy"]
backup: true
---

# Recipe: Caddy Web Server

> Tested on: Debian 12 / Ubuntu 22.04+
> Last updated: 2026-04-01

## Overview

Caddy is a modern web server with automatic HTTPS. Used as the primary reverse proxy
for all web-facing services on this machine.

## Prerequisites

- `curl` and `gpg` must be installed
- Ports 80 and 443 must be free
- DNS records for target domains must point to this machine

## Installation Steps

```bash
# Add Caddy's official APT repository
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list

# Install
apt update
apt install -y caddy

# Verify
caddy version
systemctl status caddy
```

## Configuration

### Config files to create/modify

```caddyfile
# /etc/caddy/Caddyfile — Base configuration
{
    email admin@example.com
}

# Import site-specific configs from /etc/caddy/sites/
import /etc/caddy/sites/*.caddy
```

Create the sites directory:
```bash
mkdir -p /etc/caddy/sites
```

### Environment variables

None required. Caddy reads its Caddyfile directly.

## Reverse Proxy

Not applicable — Caddy IS the reverse proxy. Other apps' recipes will include
their Caddy site blocks to be placed in `/etc/caddy/sites/<app>.caddy`.

## Health Check

```bash
systemctl is-active caddy
caddy validate --config /etc/caddy/Caddyfile
curl -sf http://localhost:80 -o /dev/null && echo "OK" || echo "FAIL"
```

## Post-Install

- Edit `/etc/caddy/Caddyfile` and set the admin email
- Create site blocks in `/etc/caddy/sites/` for each reverse-proxied app
- Reload: `systemctl reload caddy`
- Verify HTTPS: `curl -I https://your-domain.com`

## Known Issues

- Caddy auto-obtains TLS certificates via Let's Encrypt. Ensure port 80 is reachable
  from the internet for HTTP-01 challenge, or use DNS-01 challenge via a plugin.
- On systems with AppArmor, Caddy may need a profile adjustment for binding to low ports.
- `caddy reload` is preferred over `systemctl restart caddy` to avoid downtime.
