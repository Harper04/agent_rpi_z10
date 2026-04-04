# Home Assistant OS (KVM)

> **Status:** Running
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

# 2. Network bridge (eth0 → br0 bridge member, br0 gets DHCP)

# 3. Download and prepare image
wget -O haos.qcow2.xz https://github.com/home-assistant/operating-system/releases/download/<version>/haos_generic-aarch64-<version>.qcow2.xz
xz -d haos.qcow2.xz
sudo mv haos.qcow2 /var/lib/libvirt/images/haos_generic-aarch64.qcow2
sudo qemu-img resize /var/lib/libvirt/images/haos_generic-aarch64.qcow2 32G

# 4. Create VM
sudo virt-install \
  --name haos \
  --description "Home Assistant OS" \
  --os-variant generic \
  --ram 4096 \
  --memorybacking allocation.mode=ondemand \
  --vcpus 2 \
  --disk /var/lib/libvirt/images/haos_generic-aarch64.qcow2,bus=scsi \
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
| QEMU            | `10.1.0`  | apt                              |
| libvirt         | `11.6.0`  | apt                              |
| UEFI firmware   | AAVMF     | qemu-efi-aarch64 package         |

## Configuration

### VM Identity

| Key            | Value                                          |
|----------------|------------------------------------------------|
| VM name        | `haos`                                         |
| MAC address    | `<vm-mac>`                                     |
| VM IP          | `<vm-ip>` (DHCP from router)                   |
| Web UI         | `http://<vm-ip>:8123`                          |
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
| `/var/lib/libvirt/images/haos_generic-aarch64.qcow2`      | VM disk image                    |
| `/etc/libvirt/qemu/haos.xml`                              | VM definition (libvirt XML)      |
| `/usr/share/AAVMF/AAVMF_CODE.fd`                         | UEFI firmware (shared, read-only)|
| `/var/lib/libvirt/qemu/nvram/haos_VARS.fd`                | UEFI NVRAM (per-VM EFI vars)    |

## Network

| Port   | Protocol | Purpose                | Source    |
|--------|----------|------------------------|-----------|
| 8123   | TCP      | HA Web UI              | VM guest  |
| 5353   | UDP      | mDNS (device discovery)| VM guest  |

## Data & Storage

| Path                                                      | Purpose          | Backed up? |
|-----------------------------------------------------------|------------------|------------|
| `/var/lib/libvirt/images/haos_generic-aarch64.qcow2`      | VM disk          | TODO       |
| `/var/lib/libvirt/qemu/nvram/haos_VARS.fd`                | UEFI vars        | TODO       |
| `/etc/libvirt/qemu/haos.xml`                              | VM definition    | in git     |

## Health Check

```bash
sudo virsh domstate haos
sudo virsh dominfo haos
curl -sk -o /dev/null -w "%{http_code}" http://<vm-ip>:8123/
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
sudo virsh snapshot-create-as haos snap-$(date +%F) --description "pre-update"
sudo virsh snapshot-list haos
sudo virsh snapshot-revert haos <snap-name>
```

### Cold backup
```bash
sudo virsh shutdown haos
sudo cp /var/lib/libvirt/images/haos_generic-aarch64.qcow2 /backup/
sudo virsh dumpxml haos > /backup/haos-vm.xml
sudo virsh start haos
```

### USB passthrough (Zigbee/Z-Wave sticks)
```bash
# Find device: lsusb
# Create XML hostdev file, then:
sudo virsh attach-device haos --file zigbee-usb.xml --persistent
```

## Known Issues & Gotchas

- **On-demand memory**: `dominfo` shows full 4 GB as "Used memory" but actual host consumption is only touched pages (~700 MB idle).
- **OTA reboot bug**: HAOS 17.x updates may fail to reboot in KVM. Manual `virsh reboot haos` resolves it.
- **No GPIO access**: GPIO is host-only, not accessible from KVM guests.
- **No built-in Bluetooth**: Pi 5 BT is UART-attached, cannot be passed to KVM. Use a USB BT dongle.
- **USB disconnect**: Z-Wave JS soft-reset can drop USB passthrough. Workaround: udev auto-reattach rules.
- **IP may change**: VM gets DHCP from router. Consider a static lease for the VM MAC.

## Changelog

| Date       | Change                                     | Agent        |
|------------|--------------------------------------------|--------------|
| YYYY-MM-DD | Initial install HAOS in KVM with br0 bridge | orchestrator |
