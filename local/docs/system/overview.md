# System Overview

> **Last updated:** TODO
> **Last inventory run:** TODO

## Hardware

| Key              | Value                          |
|------------------|--------------------------------|
| Model            | TODO                           |
| CPU              | TODO                           |
| Architecture     | TODO (aarch64 / x86_64)       |
| RAM              | TODO                           |
| Storage          | TODO                           |
| NIC              | TODO                           |

## Operating System

| Key              | Value                          |
|------------------|--------------------------------|
| Distribution     | Ubuntu Server 24.04 LTS        |
| Kernel           | TODO                           |
| Filesystem       | TODO (ext4 / btrfs)           |
| Boot method      | TODO (UEFI / BIOS)            |
| Init system      | systemd                        |

## Disk Layout

```
# Output of lsblk
TODO
```

## Users & Access

| User       | Purpose               | Shell        | sudo? |
|------------|------------------------|--------------|-------|
| `root`     | System                 | /bin/bash    | n/a   |
| `tom`      | Primary operator       | /bin/bash    | yes   |

## Remote Access

| Method     | Port   | Restrictions              |
|------------|--------|---------------------------|
| SSH        | TODO   | key-only, no root login   |
| Tailscale  | —      | mesh VPN                  |
| Cockpit    | 9090   | via Tailscale only        |

## Managed by

This system is managed by the **sysadmin-agent** orchestrator.
Repository: `TODO (git remote URL)`
