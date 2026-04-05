# Home Assistant OS (KVM)

> **Status:** ✅ Running
> **Last verified:** 2026-04-02
> **Managed by agent:** `orchestrator`
> **Installation method:** KVM VM (HAOS generic-aarch64 qcow2)
> **Recipe:** manual

## Overview

Home Assistant OS running as a KVM virtual machine on the host. This is the
tier-1 fully supported installation method providing Supervisor, Add-ons,
auto-updates, and built-in backups. Uses on-demand memory allocation to avoid
wasting host RAM.

## Installation

```bash
# 1. Install KVM stack
sudo apt install qemu-system-arm qemu-efi-aarch64 qemu-utils \
  libvirt-daemon-system libvirt-clients virtinst bridge-utils

# 2. Network bridge (see /etc/netplan/50-cloud-init.yaml)
# eth0 → br0 bridge member, br0 gets DHCP

# 3. Download and prepare image
wget -O haos.qcow2.xz https://github.com/home-assistant/operating-system/releases/download/17.1/haos_generic-aarch64-17.1.qcow2.xz
xz -d haos.qcow2.xz
sudo mv haos.qcow2 /var/lib/libvirt/images/haos_generic-aarch64-17.1.qcow2
sudo qemu-img resize /var/lib/libvirt/images/haos_generic-aarch64-17.1.qcow2 32G

# 4. Create VM
sudo virt-install \
  --name haos \
  --description "Home Assistant OS" \
  --os-variant generic \
  --ram 4096 \
  --memorybacking allocation.mode=ondemand \
  --vcpus 2 \
  --disk /var/lib/libvirt/images/haos_generic-aarch64-17.1.qcow2,bus=scsi \
  --controller type=scsi,model=virtio-scsi \
  --import \
  --graphics none \
  --network bridge=br0,model=virtio \
  --boot uefi,firmware.feature0.name=enrolled-keys,firmware.feature0.enabled=no,firmware.feature1.name=secure-boot,firmware.feature1.enabled=no \
  --noautoconsole

# 5. Autostart
sudo virsh autostart haos
```

## Version

| Component       | Version   | Source                           |
|-----------------|-----------|----------------------------------|
| HAOS image      | `17.1`    | GitHub releases (generic-aarch64)|
| QEMU            | `10.1.0`  | apt (Ubuntu 25.10)               |
| libvirt         | `11.6.0`  | apt (Ubuntu 25.10)               |
| UEFI firmware   | AAVMF     | qemu-efi-aarch64 package         |

## Configuration

### VM Identity

| Key            | Value                                          |
|----------------|------------------------------------------------|
| VM name        | `haos`                                         |
| UUID           | `54fd2ee9-c56c-4f0f-83d5-8503e4a314dc`        |
| MAC address    | `52:54:00:9f:79:0f`                            |
| VM IP          | `192.168.2.174` (DHCP from router)             |
| Web UI         | `http://192.168.2.174:8123`                    |
| Web UI (Caddy) | `https://ha.z10.local.tiny-systems.eu`         |
| Web UI (ZT)    | `https://ha.z10.zt.tiny-systems.eu`            |
| vCPUs          | 2                                              |
| RAM (max)      | 4096 MB                                        |
| RAM allocation | on-demand (lazy — only touched pages used)     |
| Disk           | 32 GB qcow2 (virtio-scsi)                     |
| Network        | bridge br0 (virtio)                            |
| Boot           | UEFI (AAVMF, secure boot disabled)            |
| Autostart      | enabled                                        |

### Key paths — Host

| Path                                                      | Purpose                          |
|-----------------------------------------------------------|----------------------------------|
| `/var/lib/libvirt/images/haos_generic-aarch64-17.1.qcow2` | VM disk image                    |
| `/etc/libvirt/qemu/haos.xml`                              | VM definition (libvirt XML)      |
| `/usr/share/AAVMF/AAVMF_CODE.fd`                         | UEFI firmware (shared, read-only)|
| `/var/lib/libvirt/qemu/nvram/haos_VARS.fd`                | UEFI NVRAM (per-VM EFI vars)    |
| `/var/log/libvirt/qemu/haos.log`                          | QEMU log for this VM            |
| `/etc/netplan/50-cloud-init.yaml`                         | Bridge network config            |
| `/etc/netplan/50-cloud-init.yaml.bak.2026-04-02`         | Pre-bridge backup                |

### Key paths — Network bridge

| Interface | Role                | IP                |
|-----------|---------------------|-------------------|
| `eth0`    | Bridge member       | (none — enslaved) |
| `br0`     | Bridge master       | 192.168.2.173/24  |
| `vnet0`   | VM tap interface    | (none — L2 only)  |

## Network

| Port   | Protocol | Purpose                | Source    |
|--------|----------|------------------------|-----------|
| 8123   | TCP      | HA Web UI              | VM guest  |
| 5353   | UDP      | mDNS (device discovery)| VM guest  |

## Data & Storage

| Path                                                      | Purpose          | Backed up? |
|-----------------------------------------------------------|------------------|------------|
| `/var/lib/libvirt/images/haos_generic-aarch64-17.1.qcow2` | VM disk (all HA data) | TODO  |
| `/var/lib/libvirt/qemu/nvram/haos_VARS.fd`                | UEFI vars        | TODO       |
| `/etc/libvirt/qemu/haos.xml`                              | VM definition    | in git     |

## Dependencies

- Depends on: libvirt, qemu-system-arm, bridge br0, UEFI firmware
- Depended on by: (smart home automations, IoT device management)

## Health Check

```bash
# VM running?
sudo virsh domstate haos

# VM info
sudo virsh dominfo haos

# HA web UI responding?
curl -sk -o /dev/null -w "%{http_code}" http://192.168.2.174:8123/

# VM IP (via ARP)
ip neigh show dev br0 | grep 52:54:00:9f:79:0f
```

## Common Operations

### Start / Stop / Reboot
```bash
sudo virsh start haos
sudo virsh shutdown haos      # graceful
sudo virsh destroy haos       # force stop
sudo virsh reboot haos
```

### Console access
```bash
sudo virsh console haos
# Login: root (no password) — limited HAOS CLI
# Ctrl+] to exit
```

### Snapshots (qcow2)
```bash
# Create snapshot before update
sudo virsh snapshot-create-as haos snap-$(date +%F) --description "pre-update"

# List snapshots
sudo virsh snapshot-list haos

# Revert to snapshot
sudo virsh snapshot-revert haos snap-2026-04-02
```

### Cold backup
```bash
sudo virsh shutdown haos
sudo cp /var/lib/libvirt/images/haos_generic-aarch64-17.1.qcow2 /backup/
sudo virsh dumpxml haos > /backup/haos-vm.xml
sudo virsh start haos
```

### Export VM definition
```bash
sudo virsh dumpxml haos > haos-vm.xml
```

### USB passthrough (Zigbee/Z-Wave sticks)
```bash
# Find device: lsusb
# Create XML file, e.g., zigbee-usb.xml:
# <hostdev mode='subsystem' type='usb' managed='yes'>
#   <source>
#     <vendor id='0x10c4'/>
#     <product id='0xea60'/>
#   </source>
# </hostdev>

sudo virsh attach-device haos --file zigbee-usb.xml --persistent
```

### View QEMU logs
```bash
sudo cat /var/log/libvirt/qemu/haos.log
```

### HA updates
Updates are handled automatically via the HA Supervisor UI:
Settings → System → Updates

⚠️ After HAOS OTA updates, you may need: `sudo virsh reboot haos`

## Reverse Proxy (Caddy)

Proxied through Caddy at `https://ha.z10.local.tiny-systems.eu`.

- **Site block:** `/etc/caddy/sites/home-assistant.caddy`
- **DNS:** `ha.z10.local.tiny-systems.eu` → CNAME → `z10.local.tiny-systems.eu`
- **DNS (ZT):** `ha.z10.zt.tiny-systems.eu` → CNAME → `z10.zt.tiny-systems.eu`
- **Auth:** OFF (HA has its own auth)
- **trusted_proxies:** configured in HA `configuration.yaml`:
  ```yaml
  http:
    use_x_forwarded_for: true
    trusted_proxies:
      - 192.168.2.173
      - 192.168.2.32
  ```
- **Backup:** `/config/configuration.yaml.bak.2026-04-05` (pre-proxy)

### Add-ons installed for proxy setup

| Addon     | Slug       | Purpose                     | Port exposed |
|-----------|------------|-----------------------------|--------------|
| SSH & Terminal | `core_ssh` | Config file editing via SSH | disabled (was 22222 during setup) |

## Known Issues & Gotchas

- **On-demand memory**: `--memorybacking allocation.mode=ondemand` means `dominfo` shows full 4 GB as "Used memory" but actual host consumption is only what the guest touches (~700 MB idle).
- **OTA reboot bug**: HAOS 17.x updates may fail to reboot in KVM. Manual `virsh reboot haos` resolves it.
- **No GPIO access**: GPIO is host-only, not accessible from KVM guests.
- **No built-in Bluetooth**: Pi 5 BT is UART-attached, cannot be passed to KVM. Use a USB BT dongle.
- **USB disconnect**: Z-Wave JS soft-reset can drop USB passthrough. Workaround: udev auto-reattach rules.
- **IP may change**: VM gets DHCP from router. Consider a static lease for 52:54:00:9f:79:0f.
- **Host IP changed**: After bridge setup, host IP moved from .171 to .173.

## Changelog (app-specific)

| Date       | Change                                              | Agent        |
|------------|-----------------------------------------------------|--------------|
| 2026-04-05 | Added Caddy reverse proxy + DNS + trusted_proxies   | orchestrator |
| 2026-04-05 | Installed core_ssh addon for config management       | orchestrator |
| 2026-04-02 | Initial install HAOS 17.1 in KVM with br0 bridge   | orchestrator |
