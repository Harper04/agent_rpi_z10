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

### Post-proxy config (TODO)

After completing HA onboarding, add to `/config/configuration.yaml` in HA:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.2.93   # br0 — Caddy host IP
```

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

## Known Issues & Gotchas

- HAOS ignores `virsh shutdown` (ACPI). Use `virsh destroy` + `virsh start`.
- `virsh reboot` does NOT apply config changes — only destroy + start does.
- VM IP from DHCP may change. Set a static DHCP lease on router for MAC `52:54:00:40:9c:49`.
- If Caddy upstream IP changes, update `/etc/caddy/sites/home-assistant.caddy` and reload.
- trusted_proxies must be configured in HA after onboarding or reverse proxy returns HTTP 400.

## Changelog (app-specific)

| Date       | Change                                        | Agent        |
|------------|-----------------------------------------------|--------------|
| 2026-04-07 | Installed HAOS 17.2, br0 bridge, VM at 192.168.2.182 | orchestrator |
