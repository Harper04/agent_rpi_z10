# ZeroTier

> **Status:** ⚠️ Awaiting network authorization
> **Last verified:** 2026-04-02
> **Managed by agent:** `orchestrator`
> **Installation method:** `apt` (official ZeroTier repo)
> **Recipe:** manual

## Overview

ZeroTier provides a software-defined network (VPN/overlay) allowing this machine to communicate with other nodes on a private network.

## Installation

Installed via the official install script which adds the ZeroTier apt repository and installs the package.

```bash
curl -s https://install.zerotier.com | sudo bash
```

## Version

| Component    | Version  | Source |
|--------------|----------|--------|
| zerotier-one | `1.16.1` | apt    |

## Configuration

### ZeroTier Identity

| Key            | Value          |
|----------------|----------------|
| ZT Address     | `abdad38610`   |
| Network ID     | `8286ac0e476c329b` |
| Interface      | `ztrta4apg4`   |

### Config files

| File                          | Purpose              |
|-------------------------------|----------------------|
| `/var/lib/zerotier-one/`      | Identity & state     |

## Network

| Port   | Protocol | Purpose          | Exposed to      |
|--------|----------|------------------|-----------------|
| 9993   | UDP      | ZeroTier traffic | WAN/LAN         |

## Data & Storage

| Path                        | Purpose          | Backed up? |
|-----------------------------|------------------|------------|
| `/var/lib/zerotier-one/`    | Identity & config| ✅ Yes     |

## Dependencies

- Depends on: network connectivity
- Depended on by: (none yet)

## Health Check

```bash
sudo zerotier-cli status
sudo zerotier-cli listnetworks
```

## Common Operations

### Restart
```bash
systemctl restart zerotier-one
```

### View logs
```bash
journalctl -u zerotier-one --since "1 hour ago"
```

### Update
```bash
sudo apt update && sudo apt upgrade zerotier-one
```

## Known Issues & Gotchas

- Node must be authorized in the ZeroTier Central admin panel after joining a network.
- If ACCESS_DENIED persists, check https://my.zerotier.com for the network.

## Changelog (app-specific)

| Date       | Change                                     | Agent        |
|------------|--------------------------------------------|--------------|
| 2026-04-02 | Initial install v1.16.1, joined 8286ac0e476c329b | orchestrator |
