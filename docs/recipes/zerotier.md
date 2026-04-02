---
name: "zerotier"
method: apt
version: "latest"
ports: [9993]
dependencies: [curl]
reverse-proxy: false
domain: ""
data-paths: ["/var/lib/zerotier-one"]
backup: true
---

# Recipe: ZeroTier

> Tested on: Debian 12 / Ubuntu 22.04+
> Last updated: 2026-04-02

## Overview

ZeroTier is a software-defined networking layer that creates encrypted virtual
networks (overlay VPN). Nodes join a network by ID and communicate as if on
the same LAN, regardless of physical location. Useful for secure machine-to-machine
communication across sites.

## Prerequisites

- `curl` must be installed
- UDP port 9993 should be reachable (improves peer-to-peer connectivity)
- A ZeroTier network ID (create at https://my.zerotier.com or self-host a controller)

## Installation Steps

```bash
# Install via official script (adds apt repo + installs zerotier-one)
curl -s https://install.zerotier.com | sudo bash

# Verify
sudo zerotier-cli status
# Expected: 200 info <address> <version> ONLINE
```

## Configuration

### Join a network

```bash
# Join by network ID
sudo zerotier-cli join {{ NETWORK_ID }}

# Check status (will show ACCESS_DENIED until authorized)
sudo zerotier-cli listnetworks
```

### Authorize the node

The node must be authorized in ZeroTier Central (or your self-hosted controller):

1. Go to https://my.zerotier.com/network/{{ NETWORK_ID }}
2. Find the new member (by its ZT address from `zerotier-cli status`)
3. Check the "Auth" checkbox

After authorization:
```bash
sudo zerotier-cli listnetworks
# Status should change from ACCESS_DENIED to OK
```

### Config files

| File                     | Purpose              |
|--------------------------|----------------------|
| `/var/lib/zerotier-one/` | Identity, keys & state |

### Environment variables

None required. ZeroTier reads its configuration from `/var/lib/zerotier-one/`.

## Health Check

```bash
sudo zerotier-cli status
sudo zerotier-cli listnetworks
```

## Post-Install

- Authorize the node in ZeroTier Central (see above)
- Note the ZT-assigned IP from `listnetworks` output
- Optionally set a static IP in the network settings on ZeroTier Central
- Update firewall rules if needed (UDP 9993)

## Known Issues

- Node must be authorized after joining — `ACCESS_DENIED` is expected initially.
- If connectivity is poor, ensure UDP 9993 is not blocked by firewall.
- The identity in `/var/lib/zerotier-one/identity.secret` is the node's private key.
  Back it up — losing it means the node gets a new address and must be re-authorized.
- On upgrade, the service restarts automatically. Existing network memberships persist.
