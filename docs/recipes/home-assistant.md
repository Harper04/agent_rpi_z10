---
name: "home-assistant"
method: binary
version: "latest"
ports: [8123]
dependencies: [qemu-system-arm, qemu-efi-aarch64, qemu-utils, libvirt-daemon-system, libvirt-clients, virtinst, bridge-utils]
reverse-proxy: true
domain: "ha.{{ ZONE }}"
data-paths: ["/var/lib/libvirt/images"]
backup: true
---

# Recipe: Home Assistant OS (KVM)

> Tested on: Debian 12 / Ubuntu 22.04+ (amd64, arm64)
> Last updated: 2026-04-02

## Overview

Home Assistant OS running as a KVM virtual machine. This is the tier-1 fully
supported installation method providing Supervisor, Add-ons, auto-updates, and
built-in backups. Uses on-demand memory allocation to avoid wasting host RAM.

## Prerequisites

- KVM-capable host (`kvm-ok` or `grep -c vmx /proc/cpuinfo`)
- A network bridge (`br0`) for the VM to get its own LAN IP via DHCP
- At least 2 GB RAM and 32 GB disk free

```bash
sudo apt install qemu-system-arm qemu-efi-aarch64 qemu-utils \
  libvirt-daemon-system libvirt-clients virtinst bridge-utils
```

### Network bridge setup

The VM needs a bridge interface to appear on the LAN. Example netplan config:

```yaml
# /etc/netplan/50-bridge.yaml
network:
  version: 2
  ethernets:
    {{ ETH_INTERFACE }}:
      dhcp4: false
  bridges:
    br0:
      interfaces: [{{ ETH_INTERFACE }}]
      dhcp4: true
      parameters:
        stp: false
        forward-delay: 0
```

```bash
sudo netplan apply
# WARNING: Host IP will change to the bridge IP. Reconnect via new IP.
```

## Installation Steps

```bash
# 1. Determine architecture
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
  HAOS_ARCH="generic-aarch64"
elif [ "$ARCH" = "x86_64" ]; then
  HAOS_ARCH="generic-x86-64"
fi

# 2. Download latest HAOS image
# Check https://github.com/home-assistant/operating-system/releases for latest
HAOS_VERSION="{{ HAOS_VERSION }}"
wget -O haos.qcow2.xz "https://github.com/home-assistant/operating-system/releases/download/${HAOS_VERSION}/haos_${HAOS_ARCH}-${HAOS_VERSION}.qcow2.xz"

# 3. Extract and place image
xz -d haos.qcow2.xz
sudo mv haos.qcow2 /var/lib/libvirt/images/haos_${HAOS_ARCH}-${HAOS_VERSION}.qcow2
sudo qemu-img resize /var/lib/libvirt/images/haos_${HAOS_ARCH}-${HAOS_VERSION}.qcow2 32G

# 4. Create VM
sudo virt-install \
  --name haos \
  --description "Home Assistant OS" \
  --os-variant generic \
  --ram 2560 \
  --memorybacking allocation.mode=ondemand \
  --vcpus 2 \
  --disk /var/lib/libvirt/images/haos_${HAOS_ARCH}-${HAOS_VERSION}.qcow2,bus=scsi \
  --controller type=scsi,model=virtio-scsi \
  --import \
  --graphics none \
  --network bridge=br0,model=virtio \
  --boot uefi,firmware.feature0.name=enrolled-keys,firmware.feature0.enabled=no,firmware.feature1.name=secure-boot,firmware.feature1.enabled=no \
  --noautoconsole

# 5. Enable autostart
sudo virsh autostart haos
```

## Configuration

### VM defaults

| Setting       | Value            | Notes                          |
|---------------|------------------|--------------------------------|
| vCPUs         | 2                | Adjust based on workload       |
| RAM           | 2560 MB          | On-demand alloc; 4 GB wastes host RAM |
| Disk          | 32 GB qcow2      | Grows as needed                |
| Network       | bridge br0       | VM gets own LAN IP via DHCP    |
| Boot          | UEFI (no secure boot) | Required for HAOS         |

### Key paths

| Path                                          | Purpose                |
|-----------------------------------------------|------------------------|
| `/var/lib/libvirt/images/haos_*.qcow2`        | VM disk image          |
| `/etc/libvirt/qemu/haos.xml`                  | VM definition          |
| `/var/lib/libvirt/qemu/nvram/haos_VARS.fd`    | UEFI NVRAM             |
| `/var/log/libvirt/qemu/haos.log`              | QEMU log               |

### Environment variables

None. Configuration is done via the Home Assistant web UI after boot.

## Health Check

```bash
sudo virsh domstate haos
sudo virsh dominfo haos
# Check web UI (VM IP from DHCP — find via ARP or router)
curl -sk -o /dev/null -w "%{http_code}" http://{{ VM_IP }}:8123/
```

## Post-Install

- Wait ~5 minutes for first boot to complete
- Find the VM's IP: `ip neigh show dev br0` or check your router's DHCP leases
- Open `http://<vm-ip>:8123/` to complete the onboarding wizard
- Create a Home Assistant user account
- Consider setting a static DHCP lease for the VM's MAC address

## Reverse Proxy (Caddy)

HA runs on its own IP (bridge network), so Caddy proxies to a non-localhost address.
HA also requires trusted_proxies config to accept forwarded headers from Caddy.

### Caddy site block

```bash
# /etc/caddy/sites/home-assistant.caddy
# @name Home Assistant
# @icon las la-home
# @description Home automation platform
# @dashboard true
ha.{{ ZONE }}, ha.{{ ZT_ZONE }} {
    tls {
        dns route53
    }
    reverse_proxy http://{{ VM_IP }}:8123
}
```

Use the `/caddy-onboard-app` skill:
```
/caddy-onboard-app home-assistant --port 8123 --host {{ VM_IP }} --zt --no-auth
```

### HA trusted_proxies config

HA rejects `X-Forwarded-For` from untrusted IPs with HTTP 400. Add the host's
bridge IP and primary IP to HA's `configuration.yaml`:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - {{ HOST_BRIDGE_IP }}
    - {{ HOST_PRIMARY_IP }}
```

To edit `configuration.yaml` on HAOS:
1. Install the SSH & Web Terminal addon via HA supervisor API (WebSocket)
2. Configure with an authorized SSH key, expose port temporarily
3. SSH in: `ssh -p 22222 root@{{ VM_IP }}`
4. Edit `/config/configuration.yaml`
5. Validate: `POST /api/config/core/check_config`
6. Restart HA Core: `POST /api/services/homeassistant/restart`
7. Disable SSH port exposure after done

### HA API access

Create a long-lived access token in HA (Profile → Security → Long-lived access tokens).
Save to `local/.env` as `HA_TOKEN`. The HA supervisor WebSocket API (`ws://{{ VM_IP }}:8123/api/websocket`)
provides addon management that the REST API does not.

## Known Issues

- **On-demand memory**: `virsh dominfo` shows full allocation as "Used memory" but
  actual host consumption is only what the guest touches. Even so, HAOS will gradually
  touch most of the ceiling — set `--ram` to what you can actually spare (2-2.5 GB is
  fine for most setups; 4 GB wastes host RAM on small machines).
- **No balloon driver**: HAOS has no virtio-balloon, so RAM cannot be hot-adjusted.
  Changing RAM requires a full VM power cycle (`virsh destroy` + `virsh start`).
  `virsh reboot` does NOT apply config changes — only `destroy + start` does.
- **ACPI shutdown ignored**: HAOS may ignore `virsh shutdown` (ACPI signal). Use
  `virsh destroy` for reliable power-off (requires operator confirmation).
- **OTA reboot**: HAOS updates may fail to reboot in KVM. Manual `sudo virsh reboot haos` resolves it.
- **No GPIO**: GPIO is host-only, not accessible from KVM guests.
- **No built-in Bluetooth**: Use a USB BT dongle and pass it through to the VM.
- **USB passthrough**: For Zigbee/Z-Wave sticks, use `virsh attach-device` with USB vendor/product IDs.
- **IP may change**: VM gets DHCP. Set a static lease for the VM's MAC address.
- **Bridge changes host IP**: After setting up br0, the host IP moves to the bridge interface.
