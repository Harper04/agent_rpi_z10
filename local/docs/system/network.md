# Network Configuration

> **Last updated:** 2026-04-07

## Interfaces

```
1: lo — 127.0.0.1/8
2: eth0 — bridge member (no IP), link/ether 2c:cf:67:8b:01:f3
3: wlan0 — DOWN
4: br0 — 192.168.2.93/24 (STATIC, hosts eth0 + KVM VMs)
5: ztrta4apg4 — 192.168.195.217/24 (ZeroTier)
```

## IP Addresses

| Interface    | IP Address           | Type                             |
|--------------|----------------------|----------------------------------|
| lo           | 127.0.0.1            | Loopback                         |
| eth0         | (none)               | Bridge member of br0             |
| br0          | 192.168.2.93/24      | **Static (locked) — KVM bridge** |
| wlan0        | —                    | Down                             |
| ztrta4apg4   | 192.168.195.217/24   | ZeroTier overlay                 |

> ⚠ Host IP 192.168.2.93 lives on **br0**, not eth0 — see `local/docs/conventions.md → host-static-ip`.
> br0 was created for KVM VM networking. VMs get their own DHCP IPs via br0.

## Listening Ports

| Port  | Process           | Purpose              | Exposed to |
|-------|-------------------|----------------------|------------|
| 22    | sshd              | SSH access           | LAN        |
| 53    | systemd-resolved  | Local DNS stub       | localhost  |

> Generated from `ss -tlnp` on 2026-04-07

## Firewall Rules

```
UFW Status: inactive
```

No active firewall rules. SSH is exposed on all interfaces via LAN.

## DNS

| Setting       | Value              |
|---------------|--------------------|
| Nameservers   | 192.168.2.1 (router), fe80::1 |
| Search domain | (none)             |
| Resolver      | systemd-resolved (stub: 127.0.0.53) |
| MagicDNS      | not configured (Tailscale not active) |

## Tailscale

| Setting           | Value              |
|-------------------|--------------------|
| Status            | not configured     |
| Tailscale IP      | —                  |
| Advertised routes | —                  |
| Exit node         | no                 |

## Routing

```
default via 192.168.2.1 dev eth0 proto dhcp src 192.168.2.171 metric 100
192.168.2.0/24 dev eth0 proto kernel scope link src 192.168.2.171 metric 100
192.168.2.1 dev eth0 proto dhcp scope link src 192.168.2.171 metric 100
```

## Reverse Proxy (Caddy)

Not installed. No Caddyfile present.
