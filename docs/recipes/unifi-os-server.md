---
name: "unifi-os-server"
method: binary
version: "latest"
ports: [11443, 8080, 8443, 3478, 10003]
dependencies: [podman, slirp4netns]
reverse-proxy: true
domain: "unifi.{{ ZONE }}"
data-paths: ["/var/lib/uosserver", "/home/uosserver/.local/share/containers/storage/volumes"]
backup: true
---

# Recipe: UniFi OS Server

> Tested on: Ubuntu 22.04+ (amd64, arm64)
> Last updated: 2026-04-04

## Overview

UniFi OS Server (UOS) is Ubiquiti's self-hosted network management platform,
replacing the legacy UniFi Network Application. It runs as a Podman container
managed by the official `uosserver` binary. Provides the full UniFi OS experience
including Site Magic, Teleport VPN, and Site Manager.

## Prerequisites

- `podman` and `slirp4netns` must be installed
- At least 2 GB RAM free, 10 GB disk
- Architecture: amd64 or arm64

```bash
sudo apt install podman slirp4netns
```

## Installation Steps

```bash
# Download the official installer for your architecture
# Check https://ui.com/download/releases/unifi-os-server for latest URL
ARCH=$(dpkg --print-architecture)  # amd64 or arm64
wget -O /tmp/unifiosinstaller "{{ INSTALLER_URL }}"
chmod +x /tmp/unifiosinstaller

# Install (auto-confirms)
echo "y" | sudo /tmp/unifiosinstaller

# Verify
sudo uosserver status
sudo systemctl status uosserver.service
```

## Configuration

### Key paths

| Path                               | Purpose                          |
|------------------------------------|----------------------------------|
| `/usr/local/bin/uosserver`         | Main CLI binary                  |
| `/usr/local/bin/uosserver-purge`   | Uninstall binary                 |
| `/var/lib/uosserver/server.conf`   | Server configuration             |
| `/var/lib/uosserver/bin/`          | Service binaries                 |
| `/var/lib/uosserver/logs/`         | UOS service logs                 |

### Podman volumes (persistent data)

Base path: `/home/uosserver/.local/share/containers/storage/volumes/`

| Volume                         | Mount              | Purpose              |
|--------------------------------|--------------------|----------------------|
| `uosserver_data`               | `/data`            | Application data     |
| `uosserver_var_lib_unifi`      | `/var/lib/unifi`   | UniFi controller data|
| `uosserver_var_lib_mongodb`    | `/var/lib/mongodb`  | MongoDB database    |
| `uosserver_persistent`         | `/persistent`      | Persistent state     |

### Systemd services

| Unit                        | Purpose              |
|-----------------------------|----------------------|
| `uosserver.service`         | Main UOS service     |
| `uosserver-updater.service` | Auto-updater         |

### Environment variables

| Variable             | Default   | Purpose                |
|----------------------|-----------|------------------------|
| `NETWORK_MODE`       | `pasta`   | Podman network backend |

## Health Check

```bash
sudo uosserver status
sudo systemctl status uosserver.service
ss -tlnp | grep -E '(11443|8080|8443)'
curl -sk https://localhost:11443/api/ping
```

## Post-Install

- Open `https://<machine-ip>:11443/` to complete the setup wizard
- Create an admin account and adopt Ubiquiti devices
- Optionally add user to uosserver group: `sudo usermod -aG uosserver <username>`

### WebRTC remote access fix (ARM64 + pasta + bridge)

On ARM64, the installer auto-selects pasta networking. If the host's default
route goes through a bridge (`br0`), remote access via unifi.ui.com / mobile
app is broken: the WebRTC addon reads the host's `/proc/net/route` (exposed
by pasta), sees `br0`, but the container namespace only has `eth0`. ICE
gathering finds zero candidates and connections time out.

**Skip this section** if:
- Your architecture is amd64, or
- Your host's default route is on `eth0` directly (no bridge)

**Install the fix:**
```bash
# The fix script is already in the repo
chmod +x scripts/hooks/uos-webrtc-fix.sh

# Install the systemd service (adjusts path automatically)
REPO_PATH="$(pwd)"
sed "s|%REPO_PATH%|$REPO_PATH|g" templates/local/systemd/uos-webrtc-fix.service \
  | sudo tee /etc/systemd/system/uos-webrtc-fix.service > /dev/null

# Also keep a local copy for reference
mkdir -p local/systemd
sed "s|%REPO_PATH%|$REPO_PATH|g" templates/local/systemd/uos-webrtc-fix.service \
  > local/systemd/uos-webrtc-fix.service

sudo systemctl daemon-reload
sudo systemctl enable --now uos-webrtc-fix.service
```

**Verify:**
```bash
sudo systemctl status uos-webrtc-fix.service
# Should show "active (exited)" with "br0 created in container namespace"

CONMON_PID=$(pgrep -u uosserver conmon)
CONTAINER_PID=$(pgrep -P $CONMON_PID)
sudo nsenter -t $CONTAINER_PID -n ip addr show br0
```

## Reverse Proxy (Caddy)

UniFi OS serves HTTPS on port 11443 with a self-signed certificate. Caddy must use
`tls_insecure_skip_verify` to proxy to it. No post-proxy app config is needed —
UniFi accepts `X-Forwarded-For` and custom Host headers without restriction.

### Caddy site block

```bash
# /etc/caddy/sites/unifi.caddy
# @name UniFi OS
# @icon las la-wifi
# @description UniFi network controller
# @dashboard true
unifi.{{ ZONE }}, unifi.{{ ZT_ZONE }} {
    tls {
        dns route53
    }
    reverse_proxy https://{{ HOST_IP }}:11443 {
        transport http {
            tls_insecure_skip_verify
        }
    }
}
```

Use the `/caddy-onboard-app` skill:
```
/caddy-onboard-app unifi --port 11443 --https-upstream --zt --no-auth
```

### Post-proxy config

None needed. UniFi OS does not validate forwarded headers or require trusted proxy
configuration. This is simpler than most apps.

## Known Issues

- **Installer syntax**: Run the binary directly without arguments. Do not pass `install`.
- **Container runs as `uosserver` user**: All Podman storage is under `/home/uosserver/`.
- **CPU lockups on ARM64**: Reports of 100% CPU every 4-5 days. Monitor and restart if needed.
- **Many ports**: UOS binds ~15 ports. Check the full list with `ss -tlnp | grep -E '(uosserver|pasta)'`.
- **Updates**: Handled via the web UI or the built-in `uosserver-updater.service`.
- **Uninstall**: `sudo uosserver-purge` removes everything including data.
- **Legacy migration deadline**: November 2026 for migrating from legacy UniFi Network Application.
- **Remote access on ARM64 with pasta + bridge**: See Post-Install → WebRTC fix above.
