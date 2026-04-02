---
name: "unifi-os-server"
method: binary
version: "latest"
ports: [11443, 8080, 8443, 3478, 10003]
dependencies: [podman, slirp4netns]
reverse-proxy: false
domain: ""
data-paths: ["/var/lib/uosserver", "/home/uosserver/.local/share/containers/storage/volumes"]
backup: true
---

# Recipe: UniFi OS Server

> Tested on: Ubuntu 22.04+ (amd64, arm64)
> Last updated: 2026-04-02

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

## Known Issues

- **Installer syntax**: Run the binary directly without arguments. Do not pass `install`.
- **Container runs as `uosserver` user**: All Podman storage is under `/home/uosserver/`.
- **CPU lockups on ARM64**: Reports of 100% CPU every 4-5 days. Monitor and restart if needed.
- **Many ports**: UOS binds ~15 ports. Check the full list with `ss -tlnp | grep -E '(uosserver|pasta)'`.
- **Updates**: Handled via the web UI or the built-in `uosserver-updater.service`.
- **Uninstall**: `sudo uosserver-purge` removes everything including data.
- **Legacy migration deadline**: November 2026 for migrating from legacy UniFi Network Application.
