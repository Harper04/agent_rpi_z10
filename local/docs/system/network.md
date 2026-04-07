# Network Configuration

> **Last updated:** 2026-04-07

## Interfaces

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
    inet 127.0.0.1/8
    inet6 ::1/128

2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    link/ether 2c:cf:67:8b:01:f3
    inet 192.168.2.93/24 (STATIC — locked, see conventions)
    inet6 (link-local + global dynamic)

3: wlan0: <BROADCAST,MULTICAST> mtu 1500  [DOWN]
    link/ether 2c:cf:67:8b:01:f4
```

## IP Addresses

| Interface  | IP Address          | Type                        |
|------------|---------------------|-----------------------------|
| lo         | 127.0.0.1           | Loopback                    |
| eth0       | 192.168.2.93/24     | **Static (locked)**         |
| wlan0      | —                   | Down                        |

> ⚠ eth0 IP is a system constraint — see `local/docs/conventions.md → host-static-ip`.
> Never change to DHCP or another address. VMs/containers may use other IPs.

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
