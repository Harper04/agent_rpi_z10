# ZeroTier

> **Status:** ✅ Running
> **Last verified:** 2026-04-07
> **Managed by agent:** `orchestrator`
> **Installation method:** `apt` (official ZeroTier repo)
> **Recipe:** `docs/recipes/zerotier.md`

## Overview

ZeroTier creates an encrypted virtual overlay network, allowing machines to
communicate as if on the same LAN regardless of physical location. This machine
is a member of the "Core" private network.

## Installation

Installed via the official ZeroTier install script which adds the apt repo and
installs `zerotier-one`. Node was auto-authorized via ZeroTier Central API.

```bash
curl -s https://install.zerotier.com | sudo bash
sudo zerotier-cli join 8286ac0e476c329b
# Auto-authorized via API key (ZEROTIER_API_KEY in local/.env)
```

## Version

| Component    | Version  | Source              |
|--------------|----------|---------------------|
| zerotier-one | 1.16.1   | apt (download.zerotier.com/debian/noble) |

## Configuration

### Config files

| File                           | Purpose                        |
|--------------------------------|--------------------------------|
| `/var/lib/zerotier-one/`       | Identity, keys & network state |
| `/var/lib/zerotier-one/identity.secret` | Node private key (back up!) |

### Key settings

| Setting           | Value                | Notes                          |
|-------------------|----------------------|--------------------------------|
| Network ID        | `8286ac0e476c329b`   | "Core" — from `ZEROTIER_NETWORK_ID` in `.env` |
| ZT Node ID        | `d056841e9e`         | Fixed to this node's identity  |
| ZT Interface      | `ztrta4apg4`         | Auto-named by ZeroTier         |
| ZT Assigned IP    | `192.168.195.217/24` | Assigned by network controller |

### Environment variables

| Variable              | Location      | Purpose                     |
|-----------------------|---------------|-----------------------------|
| `ZEROTIER_API_KEY`    | `local/.env`  | ZeroTier Central API access |
| `ZEROTIER_NETWORK_ID` | `local/.env`  | Network to join             |

## Network

| Port  | Protocol | Purpose                     | Exposed to   |
|-------|----------|-----------------------------|--------------|
| 9993  | UDP      | ZeroTier peer-to-peer comms | Internet     |

> eth0 IP (192.168.2.93) is unaffected — see `local/docs/conventions.md → host-static-ip`.
> ZeroTier uses its own interface `ztrta4apg4` with a separate IP space.

## Data & Storage

| Path                          | Purpose          | Backed up? |
|-------------------------------|------------------|------------|
| `/var/lib/zerotier-one/`      | Identity & state | ✅ Yes — especially `identity.secret` |

## Dependencies

- Depends on: network connectivity (eth0 at 192.168.2.93)
- Depended on by: any service using ZeroTier IP for access

## Health Check

```bash
sudo zerotier-cli status
# Expected: 200 info d056841e9e 1.16.1 ONLINE

sudo zerotier-cli listnetworks
# Expected: status OK, ZT IP 192.168.195.217/24
```

## Common Operations

### Restart
```bash
sudo systemctl restart zerotier-one
```

### View logs
```bash
journalctl -u zerotier-one --since "1 hour ago"
```

### Check network membership
```bash
sudo zerotier-cli listnetworks
```

### Leave a network
```bash
sudo zerotier-cli leave 8286ac0e476c329b
```

## Known Issues & Gotchas

- Node must be authorized in ZeroTier Central after joining. Done automatically
  here via API key — but if the node identity is reset, re-authorization is needed.
- `identity.secret` in `/var/lib/zerotier-one/` is the node's private key.
  Losing it means the node gets a new address and must be re-authorized.
- If UDP 9993 is blocked, ZeroTier falls back to TCP relay (slower). Open 9993/udp
  on the router for best performance.
- ZeroTier creates its own virtual interface (`ztXXXXXX`) — it does NOT touch
  eth0 or the host's static IP.

## Changelog (app-specific)

| Date       | Change                                  | Agent        |
|------------|-----------------------------------------|--------------|
| 2026-04-07 | Installed v1.16.1, joined Core network, auto-authorized | orchestrator |
