# UniFi OS Server

> **Status:** ✅ Running
> **Last verified:** 2026-04-04
> **Managed by agent:** `orchestrator`
> **Installation method:** Official Ubiquiti installer (Podman-based)
> **Recipe:** manual

## Overview

UniFi OS Server (UOS) is Ubiquiti's self-hosted network management platform. It
replaces the legacy UniFi Network Application and provides the full UniFi OS
experience (Site Magic, Teleport VPN, Identity, Site Manager) on generic hardware.

## Installation

Downloaded the official ARM64 installer from Ubiquiti and ran it:

```bash
wget -O /tmp/unifiosinstaller "https://fw-download.ubnt.com/data/unifi-os-server/df5b-linux-arm64-5.0.6-f35e944c-f4b6-4190-93a8-be61b96c58f4.6-arm64"
chmod +x /tmp/unifiosinstaller
echo "y" | sudo ./unifiosinstaller
```

Prerequisites installed via apt:
```bash
sudo apt install podman slirp4netns
```

## Version

| Component        | Version  | Source                       |
|------------------|----------|------------------------------|
| UniFi OS Server  | `5.0.6`  | Ubiquiti official installer  |
| Container image  | `0.0.54` | docker.io/library/uosserver  |
| Podman           | `5.4.2`  | apt (Ubuntu 25.10)           |
| slirp4netns      | `1.2.1`  | apt (Ubuntu 25.10)           |

## Configuration

### UOS Identity

| Key            | Value                                          |
|----------------|------------------------------------------------|
| UOS UUID       | `fed86db9-122d-5b89-86a9-8b2e35d15b1f`         |
| Network mode   | `pasta`                                        |
| Web UI         | `https://192.168.2.32:11443/` (DHCP — may change) |

### Key paths — Binaries & config

| Path                                    | Purpose                          |
|-----------------------------------------|----------------------------------|
| `/usr/local/bin/uosserver`              | Main CLI binary                  |
| `/usr/local/bin/uosserver-purge`        | Uninstall binary                 |
| `/var/lib/uosserver/server.conf`        | Server configuration             |
| `/var/lib/uosserver/bin/`               | Service binaries (discovery, pasta, updater) |
| `/var/lib/uosserver/logs/`              | UOS service logs                 |

### Key paths — Podman volumes (persistent data)

Base path: `/home/uosserver/.local/share/containers/storage/volumes/`

| Volume name                      | Container mount         | Purpose                    |
|----------------------------------|-------------------------|----------------------------|
| `uosserver_persistent`           | `/persistent`           | Persistent state           |
| `uosserver_data`                 | `/data`                 | Application data           |
| `uosserver_srv`                  | `/srv`                  | Served content             |
| `uosserver_var_lib_unifi`        | `/var/lib/unifi`        | UniFi controller data      |
| `uosserver_var_lib_mongodb`      | `/var/lib/mongodb`      | MongoDB database           |
| `uosserver_var_log`              | `/var/log`              | Container logs             |
| `uosserver_etc_rabbitmq_ssl`     | `/etc/rabbitmq/ssl`     | RabbitMQ SSL certs         |

### Key paths — Container image storage

| Path                                                        | Purpose                |
|-------------------------------------------------------------|------------------------|
| `/home/uosserver/.local/share/containers/storage/`          | Podman storage root    |

### Key paths — Systemd services

| Unit                           | Purpose                      |
|--------------------------------|------------------------------|
| `uosserver.service`            | Main UOS service             |
| `uosserver-updater.service`    | Auto-updater service         |

### Environment variables

| Variable             | Value                                  | Purpose                |
|----------------------|----------------------------------------|------------------------|
| `UOS_UUID`           | `fed86db9-122d-5b89-86a9-8b2e35d15b1f` | Unique instance ID     |
| `UOS_SERVER_VERSION` | `5.0.6`                                | Installed version      |
| `CONTAINER_VERSION`  | `0.0.54`                               | Container image tag    |
| `NETWORK_MODE`       | `pasta`                                | Network backend        |

## Network

| Port   | Protocol | Purpose                    | Exposed to   |
|--------|----------|----------------------------|--------------|
| 11443  | TCP      | Web UI (HTTPS)             | LAN          |
| 8080   | TCP      | Device inform/adoption     | LAN          |
| 8443   | TCP      | Controller API (HTTPS)     | LAN          |
| 8444   | TCP      | Cloud access               | LAN          |
| 8880   | TCP      | HTTP portal redirect       | LAN          |
| 8881   | TCP      | Portal HTTPS               | LAN          |
| 8882   | TCP      | Portal websocket           | LAN          |
| 3478   | UDP      | STUN                       | LAN          |
| 5514   | UDP      | Remote syslog              | LAN          |
| 5005   | TCP      | Speed test                 | LAN          |
| 5671   | TCP      | RabbitMQ SSL               | localhost    |
| 6789   | TCP      | Mobile speed test           | LAN          |
| 9543   | TCP      | Unknown/reserved           | LAN          |
| 10003  | UDP      | Device discovery           | LAN          |
| 11084  | TCP      | Unknown/reserved           | LAN          |

## Data & Storage

| Path                                                                            | Purpose          | Backed up? |
|---------------------------------------------------------------------------------|------------------|------------|
| `/home/uosserver/.local/share/containers/storage/volumes/uosserver_data/`       | App data         | TODO       |
| `/home/uosserver/.local/share/containers/storage/volumes/uosserver_var_lib_unifi/` | UniFi config  | TODO       |
| `/home/uosserver/.local/share/containers/storage/volumes/uosserver_var_lib_mongodb/` | MongoDB DB   | TODO       |
| `/var/lib/uosserver/server.conf`                                                | Server config    | TODO       |

## Dependencies

- Depends on: podman, slirp4netns, network connectivity
- Depended on by: (none yet — will manage UniFi network devices)

## Health Check

```bash
# Service status
sudo systemctl status uosserver.service uosserver-updater.service

# Container status
sudo uosserver status

# Port check
ss -tlnp | grep -E '(11443|8080|8443)'

# Web UI
curl -sk https://localhost:11443/api/ping
```

## Common Operations

### Start / Stop / Restart
```bash
sudo uosserver start
sudo uosserver stop
# or via systemd:
sudo systemctl restart uosserver.service
```

### View logs
```bash
sudo journalctl -u uosserver.service --since "1 hour ago"
# Container logs:
sudo uosserver shell
# (inside container) journalctl or tail /var/log/*
```

### Shell into container
```bash
sudo uosserver shell
```

### Update
Updates are handled via the web UI or the built-in updater service.
```bash
# Check version
sudo uosserver version
# The uosserver-updater.service handles auto-updates
```

### Backup
```bash
# Via Web UI: Settings → System → Backups → Download
# Produces a .unf file that can be restored on any UOS instance
```

### Uninstall
```bash
sudo uosserver-purge
```

### CLI help
```bash
sudo uosserver help
```

## Known Issues & Gotchas

- **CPU lockups on ARM64**: Some reports of 100% CPU every 4-5 days. Monitor and restart if needed.
- **Installer syntax**: Run `./unifiosinstaller` without "install" argument.
- **Container runs as `uosserver` user**: Podman storage is under `/home/uosserver/`.
- **Add users to group**: `sudo usermod -aG uosserver <username>` to run `uosserver` commands without sudo.
- **Legacy Network Application deprecated**: Migration deadline is November 2026.
- **Remote access (cloud/app) — FIXED**: The WebRTC addon reads host's `/proc/net/route` (exposed by pasta), sees `br0` as default route, sets `allowed_interfaces=['br0']`. But the container namespace only has `eth0` (pasta TAP). ICE gathering finds zero candidates → remote access times out. **Fix**: A systemd service (`uos-webrtc-fix.service`) creates a dummy `br0` interface with the host IP inside the container namespace after each UOS start. The WebRTC addon binds to br0's IP, traffic routes through pasta's eth0. Script: `scripts/hooks/uos-webrtc-fix.sh`.
- **Installer auto-selects pasta on ARM64**: Only `pasta` and `slirp4netns` are supported network modes; `host` is not an option. The `uosserver-service` binary hardcodes container arguments and recreates the container if a hash mismatch is detected.
- **Backup restores don't carry UOS adoption**: The `.unf` backup file only covers the Network Application data. UOS-level cloud adoption (SSO binding, device identity) is per-install and must be redone after a purge/reinstall.
- **DHCP IP after relocation**: The Pi uses DHCP on `br0`. After moving to a new network/router, the IP will change. Check `ip addr show br0` for the current address.

## Changelog (app-specific)

| Date       | Change                                     | Agent        |
|------------|--------------------------------------------|--------------|
| 2026-04-02 | Initial install v5.0.6 via official ARM64 installer | orchestrator |
| 2026-04-04 | Purge & reinstall after relocation (IP changed from .171 to .32) | orchestrator |
| 2026-04-04 | Investigated WebRTC/remote access failure — pasta networking limitation, no fix | orchestrator |
| 2026-04-04 | Updated UOS UUID, IP, documented known issues | orchestrator |
| 2026-04-04 | Fixed WebRTC remote access — dummy br0 in container namespace + systemd service | orchestrator |
