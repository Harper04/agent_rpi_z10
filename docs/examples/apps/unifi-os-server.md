# UniFi OS Server

> **Status:** Running
> **Last verified:** 2026-04-04
> **Managed by agent:** `orchestrator`
> **Installation method:** Official Ubiquiti installer (Podman-based)
> **Recipe:** `docs/recipes/unifi-os-server.md`

## Overview

UniFi OS Server (UOS) is Ubiquiti's self-hosted network management platform. It
replaces the legacy UniFi Network Application and provides the full UniFi OS
experience (Site Magic, Teleport VPN, Identity, Site Manager) on generic hardware.

## Installation

Downloaded the official ARM64 installer from Ubiquiti and ran it:

```bash
wget -O /tmp/unifiosinstaller "<installer-url>"
chmod +x /tmp/unifiosinstaller
echo "y" | sudo ./unifiosinstaller
```

Prerequisites installed via apt:
```bash
sudo apt install podman slirp4netns
```

### Post-install: WebRTC remote access fix (ARM64 + pasta + bridge)

Installed per `docs/recipes/unifi-os-server.md` → Post-Install → WebRTC fix.

- Service: `uos-webrtc-fix.service` (active, enabled)
- Script: `scripts/hooks/uos-webrtc-fix.sh`
- Local unit copy: `local/systemd/uos-webrtc-fix.service`

## Version

| Component        | Version  | Source                       |
|------------------|----------|------------------------------|
| UniFi OS Server  | `5.0.6`  | Ubiquiti official installer  |
| Container image  | `0.0.54` | docker.io/library/uosserver  |
| Podman           | `5.4.2`  | apt                          |
| slirp4netns      | `1.2.1`  | apt                          |

## Configuration

### UOS Identity

| Key            | Value                                          |
|----------------|------------------------------------------------|
| UOS UUID       | `<uos-uuid>`                                   |
| Network mode   | `pasta`                                        |
| Web UI         | `https://<host-ip>:11443/`                     |

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

### Systemd services

| Unit                           | Purpose                      |
|--------------------------------|------------------------------|
| `uosserver.service`            | Main UOS service             |
| `uosserver-updater.service`    | Auto-updater service         |

### Environment variables

| Variable             | Purpose                |
|----------------------|------------------------|
| `UOS_UUID`           | Unique instance ID     |
| `UOS_SERVER_VERSION` | Installed version      |
| `CONTAINER_VERSION`  | Container image tag    |
| `NETWORK_MODE`       | Network backend        |

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
| 6789   | TCP      | Mobile speed test          | LAN          |
| 10003  | UDP      | Device discovery           | LAN          |

## Data & Storage

| Path                                                                               | Purpose          | Backed up? |
|------------------------------------------------------------------------------------|------------------|------------|
| `/home/uosserver/.local/share/containers/storage/volumes/uosserver_data/`          | App data         | TODO       |
| `/home/uosserver/.local/share/containers/storage/volumes/uosserver_var_lib_unifi/` | UniFi config     | TODO       |
| `/home/uosserver/.local/share/containers/storage/volumes/uosserver_var_lib_mongodb/` | MongoDB DB     | TODO       |
| `/var/lib/uosserver/server.conf`                                                   | Server config    | TODO       |

## Health Check

```bash
sudo systemctl status uosserver.service uosserver-updater.service
sudo uosserver status
ss -tlnp | grep -E '(11443|8080|8443)'
curl -sk https://localhost:11443/api/ping
```

## Common Operations

### Start / Stop / Restart
```bash
sudo uosserver start
sudo uosserver stop
sudo systemctl restart uosserver.service
```

### View logs
```bash
sudo journalctl -u uosserver.service --since "1 hour ago"
sudo uosserver shell
# (inside container) journalctl or tail /var/log/*
```

### Backup
```bash
# Via Web UI: Settings → System → Backups → Download
# Produces a .unf file that can be restored on any UOS instance
```

## Known Issues & Gotchas

- **CPU lockups on ARM64**: Reports of 100% CPU every 4-5 days. Monitor and restart.
- **Installer syntax**: Run `./unifiosinstaller` without "install" argument.
- **Container runs as `uosserver` user**: Podman storage under `/home/uosserver/`.
- **Remote access on ARM64 with pasta + bridge**: WebRTC addon can't find br0 in container namespace. Fix via `uos-webrtc-fix.service`. See recipe.
- **Installer auto-selects pasta on ARM64**: Only `pasta` and `slirp4netns` supported; `host` is not an option.
- **Backup restores don't carry UOS adoption**: `.unf` only covers Network App data, not UOS cloud identity.
- **Legacy Network Application deprecated**: Migration deadline November 2026.

## Changelog

| Date       | Change                                     | Agent        |
|------------|--------------------------------------------|--------------|
| 2026-04-02 | Initial install v5.0.6                     | orchestrator |
| 2026-04-04 | Fixed WebRTC remote access                 | orchestrator |
