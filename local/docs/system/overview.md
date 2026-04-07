# System Overview

> **Last updated:** 2026-04-07
> **Last inventory run:** 2026-04-07

## Hardware

| Key          | Value                              |
|--------------|------------------------------------|
| Model        | Raspberry Pi 5 Model B Rev 1.0     |
| CPU          | ARM Cortex-A76 × 4 (aarch64), 108 BogoMIPS/core |
| Architecture | aarch64                            |
| RAM          | 7.7 GiB (6.1 GiB free, no swap)   |
| Storage      | 232.9 GB NVMe (nvme0n1) + loop (snapd) |
| NIC          | eth0 (2c:cf:67:8b:01:f3), wlan0 (down) |

## Operating System

| Key          | Value                              |
|--------------|------------------------------------|
| Distribution | Ubuntu 25.10                       |
| Kernel       | Linux 6.17.0-1008-raspi            |
| Filesystem   | ext4 (nvme0n1p2), btrfs snapshots at /.snapshots |
| Boot method  | /boot/firmware (nvme0n1p1, 512 MB) |
| Init system  | systemd 257.9                      |

## Disk Layout

```
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
loop0         7:0    0  44.2M  1 loop /snap/snapd/25205
sda           8:0    1     0B  0 disk
sr0          11:0    1  1024M  0 rom
nvme0n1     259:0    0 232.9G  0 disk
├─nvme0n1p1 259:1    0   512M  0 part /boot/firmware
└─nvme0n1p2 259:2    0 232.3G  0 part /.snapshots /
```

## Users & Access

| User         | Purpose               | Shell        | sudo? |
|--------------|-----------------------|--------------|-------|
| `root`       | System                | /bin/bash    | n/a   |
| `tomjaster`  | Primary operator      | /bin/bash    | yes   |

## Remote Access

| Method     | Port | Restrictions              |
|------------|------|---------------------------|
| SSH        | 22   | openssh-server            |
| Tailscale  | —    | not configured            |

## Managed by

This system is managed by the **sysadmin-agent** orchestrator.
Repository: `https://github.com/Harper04/agent_rpi_s85.git`
Upstream template: `https://github.com/harper04/agent-sysadmin.git`
