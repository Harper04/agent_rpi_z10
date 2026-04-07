# Home Assistant

> **Status:** ✅ Running
> **Last verified:** 2026-04-07
> **Managed by agent:** `kvm`
> **Installation method:** KVM VM (HAOS qcow2 image)
> **Recipe:** `docs/recipes/home-assistant.md`

## Overview

Home Assistant OS running as a KVM virtual machine. Provides Supervisor, Add-ons,
auto-updates, and built-in backups. VM gets its own LAN IP via DHCP through the
host's br0 bridge.

## Installation

```bash
# Image: HAOS 17.2 generic-aarch64
# Downloaded from GitHub releases, resized to 32 GB
sudo virt-install --name haos ... --network bridge=br0,model=virtio
sudo virsh autostart haos
```

## Version

| Component         | Version            | Source                              |
|-------------------|--------------------|-------------------------------------|
| HAOS image        | 17.2               | github.com/home-assistant/operating-system |
| QEMU/KVM          | system             | apt                                 |

## VM Configuration

| Setting    | Value                                          |
|------------|------------------------------------------------|
| vCPUs      | 2                                              |
| RAM        | 2560 MB (on-demand allocation)                 |
| Disk       | 32 GB qcow2 at `/var/lib/libvirt/images/haos_generic-aarch64-17.2.qcow2` |
| Network    | bridge=br0, model=virtio, MAC=52:54:00:40:9c:49 |
| Boot       | UEFI (no secure boot)                          |
| Autostart  | yes                                            |

## Network

| Host/VM      | IP              | Interface  | Notes                    |
|--------------|-----------------|------------|--------------------------|
| Host (Pi)    | 192.168.2.93    | br0        | Static, locked           |
| HAOS VM      | 192.168.2.182   | br0 (DHCP) | Set static lease by MAC  |

> ⚠ VM IP may change on DHCP renewal. Recommend setting a static DHCP lease
> for MAC `52:54:00:40:9c:49` in your router to lock it to 192.168.2.182.

## Reverse Proxy (Caddy)

| Key        | Value                                          |
|------------|------------------------------------------------|
| Site block | `/etc/caddy/sites/home-assistant.caddy`        |
| ZT domain  | `https://ha.s85.zt.tiny-systems.eu/`           |
| LAN domain | `https://ha.s85.local.tiny-systems.eu/`        |
| Auth       | OFF (HA has its own login)                     |
| Upstream   | `http://192.168.2.182:8123`                    |

### Post-proxy config ✅

`/homeassistant/configuration.yaml` in HA contains:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.2.93   # br0 — Caddy host IP
```

Applied via HAOS console on 2026-04-07. Verified: Caddy proxy returns HTTP 200.

## Data & Storage

| Path                                                        | Purpose          | Backed up? |
|-------------------------------------------------------------|------------------|------------|
| `/var/lib/libvirt/images/haos_generic-aarch64-17.2.qcow2`  | VM disk image    | ✅ Yes     |
| `/etc/libvirt/qemu/haos.xml`                                | VM definition    | ✅ Yes     |

## Health Check

```bash
sudo virsh domstate haos
curl -sk -o /dev/null -w "%{http_code}" http://192.168.2.182:8123/
```

## Common Operations

### Start / Stop / Restart VM
```bash
sudo virsh start haos
sudo virsh destroy haos    # force off (ACPI shutdown often ignored by HAOS)
sudo virsh start haos
```

### View VM console
```bash
sudo virsh console haos    # Ctrl+] to exit
```

### Change RAM (requires power cycle)
```bash
sudo virsh destroy haos
sudo virsh setmaxmem haos 4G --config
sudo virsh setmem haos 4G --config
sudo virsh start haos
```

## SSH Access

| Setting    | Value                             |
|------------|-----------------------------------|
| Addon      | Terminal & SSH (core_ssh) v10.0.2 |
| SSH Port   | 22222 (mapped from container:22)  |
| Auth       | Key-only (no password)            |
| Key        | `~/.ssh/id_ed25519_ha` on Pi host |
| Pub key    | `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ1MvaVPWM9lf4HvgyKf1KM7EZuLO4C96lCp/tWkuTvn sysadmin-agent@strandstr-pi` |

```bash
ssh -i ~/.ssh/id_ed25519_ha -p 22222 root@192.168.2.182
```

### Useful SSH commands inside HAOS
```bash
ha core restart        # restart HA core (applies config changes)
ha core info           # HA version info
ha apps list           # list installed addons
ha os reboot           # full HAOS reboot
cat /homeassistant/configuration.yaml  # view HA config
```

### How port was configured (2026-04-07)

Default port mapping is `null` (disabled). Configured via Supervisor API:
```bash
# From HAOS bash shell (virsh console haos → root login):
TOKEN=$(cat /mnt/data/supervisor/cli.json | grep access_token | cut -d'"' -f4)
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"options":{"authorized_keys":["..."],"password":"","apks":[],"server":{"tcp_forwarding":false}},"network":{"22/tcp":22222}}' \
  http://172.30.32.2/addons/core_ssh/options
ha apps restart core_ssh
```

## Known Issues & Gotchas

- HAOS ignores `virsh shutdown` (ACPI). Use `virsh destroy` + `virsh start`.
- `virsh reboot` does NOT apply config changes — only destroy + start does.
- VM IP from DHCP may change. Set a static DHCP lease on router for MAC `52:54:00:40:9c:49`.
- If Caddy upstream IP changes, update `/etc/caddy/sites/home-assistant.caddy` and reload.
- trusted_proxies must be configured in HA after onboarding or reverse proxy returns HTTP 400. ✅ Done.
- SSH addon port `22/tcp` defaults to `null` (disabled). Must be set via Supervisor API — not by editing options.json directly (Supervisor overwrites it). ✅ Done — port 22222 active.
- No python3 in HAOS host bash. Use `awk`/`sed`/`grep` for text processing or write files via `cat > file`.
- Supervisor CLI token (for API access from host bash): `/mnt/data/supervisor/cli.json` → `access_token` field. Supervisor API at `http://172.30.32.2/`.

## Changelog (app-specific)

| Date       | Change                                        | Agent        |
|------------|-----------------------------------------------|--------------|
| 2026-04-07 | Installed HAOS 17.2, br0 bridge, VM at 192.168.2.182 | orchestrator |
| 2026-04-07 | configured trusted_proxies (192.168.2.93), enabled SSH addon port 22222, verified Caddy proxy HTTP 200 | orchestrator |
