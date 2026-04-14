# UniFi OS Server (uosserver)

> **Status:** Running
> **Last verified:** 2026-04-07
> **Managed by agent:** `docker`
> **Installation method:** `podman` (rootless, system service)
> **Recipe:** manual (Ubiquiti proprietary installer)

## Overview

UniFi OS Server v5.0.6 — Ubiquiti's container-based UniFi controller platform.
Runs as a rootless podman container under the `uosserver` system user, managed
by the proprietary `uosserver-service` binary. The container includes UniFi Network
(network device management), UniFi Core, PostgreSQL, MongoDB, RabbitMQ, nginx,
and several Ubiquiti microservices.

Installed to allow adoption and management of UniFi network devices on the LAN.

## Installation

Downloaded and run the Ubiquiti installer binary:

```bash
sudo apt install -y podman slirp4netns
wget -O /tmp/unifiosinstaller "https://fw-download.ubnt.com/data/unifi-os-server/df5b-linux-arm64-5.0.6-f35e944c-f4b6-4190-93a8-be61b96c58f4.6-arm64"
chmod +x /tmp/unifiosinstaller
echo "y" | sudo /tmp/unifiosinstaller
```

### Ubuntu 25.10 / Kernel 6.17 Compatibility Fixes

The stock installer fails on Ubuntu 25.10 with cgroup v2 due to two issues:

**Fix 1: cgroup scope creation failure**

The installer's systemd service unit lacks `Delegate=yes`. On kernel 6.17, podman
running as a non-root user under a system service cannot create cgroup scopes in the
user slice. Added `Delegate=yes` to the service and configured podman to use
`cgroupfs` cgroup manager (not `systemd`) to bypass scope creation entirely.

Files modified:
- `/etc/systemd/system/uosserver.service` — added `Delegate=yes`
- `/etc/systemd/system/uosserver.service.d/10-cgroup-fix.conf` — sets `CONTAINERS_CONF_OVERRIDE`
- `/etc/uosserver/containers-override.conf` — forces `cgroup_manager = "cgroupfs"`

**Fix 2: WebRTC remote access**

The container's pasta network namespace only has `eth0` (tap), but the host's
default route is via `br0`. The WebRTC addon reads `/proc/net/route`, sees `br0`,
but finds no matching interface inside the container — resulting in no ICE candidates
and remote access timeouts.

Fix: `uos-webrtc-fix.service` runs after `uosserver.service` and creates a dummy
`br0` interface in the container network namespace with the host's IP (192.168.2.93).

## Version

| Component       | Version   | Source                      |
|-----------------|-----------|-----------------------------|
| uosserver       | `5.0.6`   | Ubiquiti installer binary   |
| container image | `0.0.54`  | docker.io/library/uosserver |
| podman          | `5.4.2`   | Ubuntu apt                  |

## Configuration

### Config files

| File                                             | Purpose                                      |
|--------------------------------------------------|----------------------------------------------|
| `/var/lib/uosserver/server.conf`                 | UOS UUID, container version, image name      |
| `/etc/systemd/system/uosserver.service`          | Host systemd service                         |
| `/etc/systemd/system/uosserver.service.d/10-cgroup-fix.conf` | cgroup fix drop-in       |
| `/etc/uosserver/containers-override.conf`        | podman cgroup_manager=cgroupfs override      |
| `/home/uosserver/.config/containers/containers.conf` | podman helper_binaries_dir             |
| `/home/uosserver/.config/containers/storage.conf`   | overlay storage driver                  |
| `/etc/systemd/system/uos-webrtc-fix.service`     | WebRTC br0 fix (runs once after start)       |
| `local/systemd/uos-webrtc-fix.service`           | Repo copy of WebRTC fix service              |

### Key settings

- `NETWORK_MODE=pasta` — rootless container networking via pasta/TAP
- `cgroup_manager = "cgroupfs"` — bypasses systemd scope creation (required on Ubuntu 25.10)
- `UOS_UUID=510f56d9-53b5-5711-b402-0a7962197e67` — unique installation identifier

## Network

| Port  | Protocol | Purpose                       | Exposed to |
|-------|----------|-------------------------------|------------|
| 11443 | TCP      | UniFi OS HTTPS UI (→ :443)    | LAN        |
| 8080  | TCP      | UniFi device inform           | LAN        |
| 8443  | TCP      | UniFi HTTPS                   | LAN        |
| 8444  | TCP      | UniFi portal HTTPS            | LAN        |
| 8880  | TCP      | UniFi portal HTTP             | LAN        |
| 8881  | TCP      | UniFi guest portal            | LAN        |
| 8882  | TCP      | UniFi guest portal            | LAN        |
| 3478  | UDP      | STUN                          | LAN        |
| 5514  | UDP      | Syslog                        | LAN        |
| 10003 | UDP      | UniFi device discovery        | LAN        |
| 6789  | TCP      | UniFi speed test              | LAN        |
| 5671  | TCP      | AMQP/RabbitMQ                 | LAN        |
| 5005  | TCP      | Remote debug                  | LAN        |
| 9543  | TCP      | Internal                      | LAN        |
| 11084 | TCP      | Internal                      | LAN        |

Access UniFi OS at: `https://192.168.2.93:11443`

## Data & Storage

| Path                                                         | Purpose              | Backed up? |
|--------------------------------------------------------------|----------------------|------------|
| `/home/uosserver/.local/share/containers/storage/volumes/`  | All podman volumes   | No         |
| `uosserver_data`                                             | App data             | No         |
| `uosserver_var_lib_unifi`                                    | UniFi Network data   | No         |
| `uosserver_var_lib_mongodb`                                  | MongoDB data         | No         |
| `uosserver_persistent`                                       | Persistent UOS state | No         |

## Dependencies

- Depends on: `podman`, `passt` (pasta), `conmon`, `crun`, `slirp4netns`
- Depended on by: `uos-webrtc-fix.service`

## Health Check

```bash
sudo uosserver status
sudo systemctl status uosserver.service --no-pager
ss -tlnp | grep 11443
```

## Common Operations

### Restart
```bash
sudo systemctl restart uosserver.service
```

### View logs
```bash
# Host service logs
journalctl -u uosserver.service --since "1 hour ago"
# Container logs (run as uosserver user)
sudo bash -c 'cd /tmp && su -s /bin/bash uosserver -c "XDG_RUNTIME_DIR=/run/user/1001 podman logs uosserver --tail=50"'
```

### Container shell
```bash
sudo bash -c 'cd /tmp && su -s /bin/bash uosserver -c "XDG_RUNTIME_DIR=/run/user/1001 podman exec -it uosserver bash"'
```

### Update
```bash
# Download and run new installer; it handles container replacement
wget -O /tmp/unifiosinstaller "<new-installer-url>"
chmod +x /tmp/unifiosinstaller
echo "y" | sudo /tmp/unifiosinstaller
```

## Known Issues & Gotchas

1. **cgroup scope failure on Ubuntu 25.10**: The stock installer does not add
   `Delegate=yes` to the service unit, and podman's systemd cgroup manager cannot
   create scopes when running from a system service on kernel 6.17. Fixed by
   `/etc/systemd/system/uosserver.service.d/10-cgroup-fix.conf` forcing `cgroupfs`.

2. **Container created outside the service**: After the initial installer failure,
   the container was deleted. The `uosserver-service` binary's "start existing
   container" mode failed because no container existed. Had to manually create it
   with `podman create` (matching the original arg hash) before the service could
   start it.

3. **WebRTC / remote access**: Container's pasta `eth0` has no `br0` interface.
   WebRTC addon reads host routing and expects `br0`. Fixed by `uos-webrtc-fix.service`
   which creates a dummy `br0` with IP 192.168.2.93 in the container namespace at boot.

4. **Reboot persistence of WebRTC fix**: `uos-webrtc-fix.service` is a oneshot that
   runs after `uosserver.service`. After each reboot, it re-creates `br0` in the
   new container namespace. The dummy interface only lives in the namespace — it does
   not affect host networking.

## Changelog (app-specific)

| Date       | Change                                          | Agent        |
|------------|-------------------------------------------------|--------------|
| 2026-04-07 | Initial installation v5.0.6; cgroup + WebRTC fixes applied | docker |
