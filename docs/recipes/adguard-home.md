---
name: "adguard-home"
method: podman
version: "latest (digest-pinned)"
ports: [53, 3000]
dependencies: [podman]
reverse-proxy: true
domain: ""
data-paths: ["/opt/adguardhome/conf", "/opt/adguardhome/work"]
backup: true
---

# Recipe: AdGuard Home

> Tested on: Ubuntu 24.04+
> Last updated: 2026-04-02

## Overview

AdGuard Home is a network-wide DNS ad/tracker blocker with a web UI. This recipe
deploys it as an **internet-facing upstream DNS server** on a public VPS. Home
network AdGuard Home instances sync their configuration from this instance via the
API, making it the central source of truth for filter lists and rules.

**Architecture role:**
```
End devices ──────► min-core:53 (AdGuard Home)
Home AGH instances ► min-core:53 (upstream DNS)
Home AGH instances ◄── sync ── min-core:3000/api
systemd-resolved stays on 127.0.0.53 (host DNS, untouched)
```

## Prerequisites

- `podman` (rootful, for binding port 53)
- systemd-resolved must only listen on loopback (default on Ubuntu 24.04)
- Public IP available for DNS binding

```bash
# Verify resolved is loopback-only (should show 127.0.0.53 / 127.0.0.54)
ss -tlnp | grep ':53 '
```

## Installation Steps

### 1. Install Podman

```bash
apt update && apt install -y podman
podman --version
```

### 2. Create data directories

```bash
mkdir -p /opt/adguardhome/{conf,work}
```

### 3. Pull the image and record the digest

```bash
podman pull docker.io/adguard/adguardhome:latest

# Record exact digest for reproducibility
DIGEST=$(podman inspect --format '{{.Digest}}' docker.io/adguard/adguardhome:latest)
echo "Pulled: $(date -Is) | Digest: ${DIGEST}" >> /opt/adguardhome/image-history.log
echo "${DIGEST}"
```

### 4. Create the container

```bash
podman create \
  --name adguardhome \
  --net=host \
  --restart=always \
  -v /opt/adguardhome/conf:/opt/adguardhome/conf \
  -v /opt/adguardhome/work:/opt/adguardhome/work \
  docker.io/adguard/adguardhome:latest
```

**Why `--net=host`:** AdGuard Home needs to bind DNS on the public IP (port 53)
while systemd-resolved holds 127.0.0.53. Host networking avoids NAT complexity
and gives AGH direct access to bind specific addresses.

### 5. Create systemd Quadlet unit

Ubuntu 24.04 ships Podman 4.9 which supports Quadlet — the native way to manage
containers via systemd (replaces the deprecated `podman generate systemd`).

```bash
cat > /etc/containers/systemd/adguardhome.container <<'EOF'
[Unit]
Description=AdGuard Home DNS
After=network-online.target
Wants=network-online.target

[Container]
Image=docker.io/adguard/adguardhome:latest
ContainerName=adguardhome
Network=host
Volume=/opt/adguardhome/conf:/opt/adguardhome/conf
Volume=/opt/adguardhome/work:/opt/adguardhome/work
AutoUpdate=registry

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now adguardhome.service
```

**`AutoUpdate=registry`** lets `podman auto-update` check for new images — used
in the update procedure below.

### 6. Firewall

```bash
ufw allow 53/tcp comment "AdGuard Home DNS"
ufw allow 53/udp comment "AdGuard Home DNS"
ufw allow 3000/tcp comment "AdGuard Home Web UI (temporary, until Caddy)"
# Enable ufw if not yet active
ufw --force enable
```

## Configuration

### Initial setup wizard

1. Open `http://<PUBLIC_IP>:3000`
2. Set admin username and password
3. Configure DNS listen address: `178.104.28.233` (NOT 0.0.0.0)
4. Complete the wizard

### Post-wizard hardening (`/opt/adguardhome/conf/AdGuardHome.yaml`)

Key settings to apply after initial setup:

```yaml
dns:
  bind_hosts:
    - 178.104.28.233       # Public IPv4 only, not 0.0.0.0
  port: 53
  ratelimit: 30            # Queries per second per client (anti-abuse)
  refuse_any: true         # Refuse ANY queries (DNS amplification protection)
  upstream_dns:
    - https://dns.cloudflare.com/dns-query
    - https://dns.google/dns-query
    - tls://1.1.1.1
    - tls://8.8.8.8
  bootstrap_dns:
    - 1.1.1.1
    - 8.8.8.8
  allowed_clients:         # CRITICAL: prevent open resolver abuse
    - 127.0.0.0/8
    # Add your home network public IPs here
    # - <home-ip-1>
    # - <home-ip-2>
  cache_size: 10485760     # 10 MB DNS cache
  cache_ttl_min: 300       # 5 min minimum cache

http:
  address: 0.0.0.0:3000   # Temporary; lock down with Caddy later

filtering:
  rewrites: []
  safebrowsing_enabled: true
  parental_enabled: false
```

### Environment variables

None required. All configuration is in `AdGuardHome.yaml`.

## Reverse Proxy

Currently: port 3000 exposed directly (temporary).

Future plan — Caddy with caddy-security plugin:

```caddyfile
# dns.example.com {
#     reverse_proxy localhost:3000
#     # caddy-security auth config here
# }
```

## Health Check

```bash
# Container running?
podman ps --filter name=adguardhome --format "{{.Status}}"

# Systemd unit healthy?
systemctl is-active adguardhome.service

# DNS responding?
dig @178.104.28.233 example.com +short +time=2

# Web UI reachable?
curl -sf -o /dev/null -w "%{http_code}" http://178.104.28.233:3000/
```

## Image Update Procedure

### Quick update (using podman auto-update)

The Quadlet unit has `AutoUpdate=registry`. This enables one-command updates:

```bash
# Dry-run: check if a new image exists without pulling
podman auto-update --dry-run

# Apply update (pulls new image, restarts container)
podman auto-update
```

### Manual update with full logging

```bash
# 1. Record current digest
OLD_DIGEST=$(podman inspect --format '{{.Digest}}' docker.io/adguard/adguardhome:latest)

# 2. Pull new latest
podman pull docker.io/adguard/adguardhome:latest
NEW_DIGEST=$(podman inspect --format '{{.Digest}}' docker.io/adguard/adguardhome:latest)

# 3. Compare
if [ "${OLD_DIGEST}" = "${NEW_DIGEST}" ]; then
  echo "Already current: ${OLD_DIGEST}"
  exit 0
fi

echo "Updating: ${OLD_DIGEST} → ${NEW_DIGEST}"

# 4. Log the change
echo "Updated: $(date -Is) | Old: ${OLD_DIGEST} | New: ${NEW_DIGEST}" \
  >> /opt/adguardhome/image-history.log

# 5. Restart via systemd (Quadlet recreates from latest image)
systemctl restart adguardhome.service

# 6. Verify
sleep 3
dig @178.104.28.233 example.com +short +time=2 && echo "DNS OK" || echo "DNS FAIL"
curl -sf http://178.104.28.233:3000/ > /dev/null && echo "UI OK" || echo "UI FAIL"
```

### Scheduled update check (optional)

```bash
# Enable the built-in podman auto-update timer (checks daily)
systemctl enable --now podman-auto-update.timer
```

**Rollback to previous version:**
```bash
# Get the old digest from the log or app doc
podman pull docker.io/adguard/adguardhome@sha256:<old-digest>
podman tag docker.io/adguard/adguardhome@sha256:<old-digest> docker.io/adguard/adguardhome:latest
systemctl restart adguardhome.service
```

## Downstream Sync

Home network AdGuard Home instances sync from this server using
[AdGuardHome-Sync](https://github.com/bakito/adguardhome-sync) or direct API calls.

**Sync endpoint:** `http://<PUBLIC_IP>:3000` (later: HTTPS via Caddy)

**What syncs downstream:**
- Filter lists and custom rules
- DNS rewrites
- Client settings
- Blocked services list

**What stays local per instance:**
- DNS listen addresses
- Upstream DNS servers (may differ per network)
- DHCP settings
- Query log and statistics

## Security Considerations (Internet-Facing)

| Risk                    | Mitigation                                      |
|-------------------------|-------------------------------------------------|
| Open resolver abuse     | `allowed_clients` whitelist in AGH config       |
| DNS amplification (DDoS)| `refuse_any: true`, `ratelimit: 30`             |
| Web UI brute force      | Strong password; Caddy + caddy-security (later) |
| Unencrypted DNS queries | DoH/DoT available (enable when ready)           |
| Config tampering        | Backup conf dir; changelog tracks changes       |

## Backup

Include in backup schedule:
- `/opt/adguardhome/conf/` — configuration (YAML + filter caches)
- `/opt/adguardhome/image-history.log` — image version trail

Query logs and statistics in `/opt/adguardhome/work/` are optional backup targets.

## Post-Install

1. Complete setup wizard at `http://<PUBLIC_IP>:3000`
2. Set strong admin password
3. Change DNS bind from `0.0.0.0` to `178.104.28.233` in settings
4. Add home network public IPs to allowed clients
5. Enable rate limiting (30 qps default)
6. Add filter lists (AdGuard Default, OISD, etc.)
7. Test from a home device: `dig @178.104.28.233 example.com`
8. Document final config in `local/docs/apps/adguard-home.md`

## Known Issues

- `--net=host` means AGH sees real client IPs (good for per-client stats) but
  also means it could clash with any other service on the same ports
- This recipe uses Quadlet (`.container` files) which requires Podman >= 4.4.
  Ubuntu 24.04 ships Podman 4.9 so this is fine. Older distros need `podman generate systemd` instead
- If systemd-resolved is reconfigured to listen on all interfaces, it will
  conflict with AGH on port 53 — verify after OS upgrades
