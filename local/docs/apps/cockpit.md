# Cockpit

> **Status:** Running
> **Last verified:** 2026-04-07
> **Managed by agent:** `orchestrator`
> **Installation method:** `apt`
> **Recipe:** manual

## Overview

Cockpit is a web-based server management UI providing a graphical interface for
monitoring system resources, managing containers (Podman), managing KVM virtual
machines, and managing storage. Installed to give the operator a web-based view
into the system alongside the Telegram/CLI agent interface.

## Installation

Installed via apt from Ubuntu universe repository.

```bash
sudo apt-get install -y cockpit cockpit-podman cockpit-machines cockpit-storaged
```

Note: `cockpit-networkmanager` was pulled in as an automatic dependency along
with `network-manager`. NetworkManager was not previously active on this system
(netplan manages networking). The NetworkManager service started post-install but
has not been configured to manage any interfaces — eth0/br0 static IP
(192.168.2.93) remains under netplan control.

## Version

| Component              | Version | Source |
|------------------------|---------|--------|
| cockpit                | 346-1   | apt (ubuntu questing/universe) |
| cockpit-machines       | 339-1   | apt (ubuntu questing/universe) |
| cockpit-networkmanager | 346-1   | apt (ubuntu questing/universe, pulled as dep) |
| cockpit-podman         | 113-1   | apt (ubuntu questing/universe) |
| cockpit-storaged       | 346-1   | apt (ubuntu questing/universe) |

## Configuration

### Config files

| File                                                        | Purpose                          |
|-------------------------------------------------------------|----------------------------------|
| `/etc/cockpit/cockpit.conf`                                 | WebService origins & TLS config  |
| `/etc/systemd/system/cockpit.socket.d/listen.conf`          | Restrict socket to localhost only |

### Key settings

**cockpit.conf** — Allows Caddy-proxied access by listing the proxy domains as
trusted origins. Cockpit validates the `Origin` header on WebSocket connections
and would reject proxied requests without this.

```ini
[WebService]
Origins = https://cockpit.s85.local.tiny-systems.eu https://cockpit.s85.zt.tiny-systems.eu
AllowUnencrypted = false
```

**listen.conf** — Overrides the default socket to listen only on localhost,
preventing direct external access. The empty `ListenStream=` clears the default
(`:9090` on all interfaces) before adding the restricted binding.

```ini
[Socket]
ListenStream=
ListenStream=127.0.0.1:9090
```

### Environment variables

None.

## Network

| Port | Protocol | Purpose              | Exposed to       |
|------|----------|----------------------|------------------|
| 9090 | TCP      | Cockpit web UI       | localhost only   |

All external access via Caddy reverse proxy over HTTPS.

## Data & Storage

| Path                    | Purpose                 | Backed up? |
|-------------------------|-------------------------|------------|
| `/etc/cockpit/`         | Cockpit configuration   | No (config in repo docs) |
| `/var/lib/cockpit/`     | Cockpit runtime data    | No         |

## Dependencies

- Depends on: `libvirt` (for cockpit-machines KVM management), `podman` (for cockpit-podman)
- Depended on by: Nothing — UI-only tool

## Health Check

```bash
systemctl status cockpit.socket
ss -tlnp | grep 9090
curl -sk http://127.0.0.1:9090/ | head -5
```

## Common Operations

### Restart
```bash
sudo systemctl restart cockpit.socket
```

### View logs
```bash
journalctl -u cockpit --since "1 hour ago"
```

### Update
```bash
sudo apt-get install --only-upgrade cockpit cockpit-podman cockpit-machines cockpit-storaged
```

## Reverse Proxy (Caddy)

| Key        | Value                                                        |
|------------|--------------------------------------------------------------|
| Site block | `/etc/caddy/sites/cockpit.caddy`                             |
| LAN domain | `https://cockpit.s85.local.tiny-systems.eu/`                 |
| ZT domain  | `https://cockpit.s85.zt.tiny-systems.eu/`                    |
| Auth       | OFF                                                          |
| Upstream   | `http://127.0.0.1:9090`                                      |

### Post-proxy config

The `Origins` setting in `/etc/cockpit/cockpit.conf` tells Cockpit to accept
WebSocket connections arriving with the Caddy proxy domains as the Origin header.
Without this, Cockpit rejects all proxied WebSocket connections (returns 403).

Caddy passes `header_up Host {upstream_addr}` to satisfy Cockpit's host
validation requirements for proxied connections.

## Known Issues & Gotchas

- **NetworkManager installed as dependency.** NetworkManager is now active on the
  system. It has not been configured to manage any interface. Monitor to ensure
  it does not interfere with netplan's management of eth0/br0 and the static IP
  192.168.2.93. If issues arise, add unmanaged=true to NetworkManager.conf or
  stop/disable the NetworkManager service.
- **cockpit-networkmanager installed.** This plugin shows the Network tab in
  Cockpit. Since networking is managed by netplan (not NetworkManager), changes
  made via the Cockpit Network tab may not persist correctly.
- **caddy validate reports a pre-existing auth error.** The `caddy validate`
  command exits non-zero due to an existing auth/security plugin provisioning
  issue unrelated to the cockpit site. Caddy itself reloads and serves
  cockpit.caddy correctly — verified by `systemctl reload caddy` succeeding.

## Changelog (app-specific)

| Date       | Change                                               | Agent        |
|------------|------------------------------------------------------|--------------|
| 2026-04-07 | Initial installation with podman/machines/storaged   | orchestrator |
