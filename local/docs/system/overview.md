# System Overview

> **Last updated:** 2026-04-02
> **Last inventory run:** 2026-04-02

## Hardware

| Key              | Value                          |
|------------------|--------------------------------|
| Model            | Hetzner vServer (KVM)          |
| CPU              | Intel Xeon (Skylake) 2x @ 2.1GHz |
| Architecture     | x86_64                         |
| RAM              | 3.7 GiB                        |
| Storage          | 38.1 GB (sda)                  |
| NIC              | eth0 (virtio)                  |

## Operating System

| Key              | Value                          |
|------------------|--------------------------------|
| Distribution     | Ubuntu 24.04.3 LTS             |
| Kernel           | 6.8.0-90-generic               |
| Filesystem       | ext4                           |
| Boot method      | UEFI (GPT, EFI partition)      |
| Init system      | systemd                        |

## Disk Layout

```
NAME    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda       8:0    0 38.1G  0 disk 
├─sda1    8:1    0 37.9G  0 part /
├─sda14   8:14   0    1M  0 part 
└─sda15   8:15   0  256M  0 part /boot/efi
sr0      11:0    1 1024M  0 rom  
```

### Disk Usage

| Filesystem | Size | Used | Avail | Use% | Mounted on |
|------------|------|------|-------|------|------------|
| /dev/sda1  | 38G  | 2.1G | 34G   | 6%   | /          |
| /dev/sda15 | 253M | 146K | 252M  | 1%   | /boot/efi  |

## Users & Access

| User       | Purpose               | Shell        | sudo? |
|------------|------------------------|--------------|-------|
| `root`     | System                 | /bin/bash    | n/a   |
| `ubuntu`   | Primary operator       | /bin/bash    | yes   |

## Remote Access

| Method     | Port   | Restrictions              |
|------------|--------|---------------------------|
| SSH        | 22     | Password + key            |

## Managed by

This system is managed by the **sysadmin-agent** orchestrator.
Repository: `https://github.com/harper04/agent_mini_core.git`
