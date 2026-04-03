# Network Configuration

> **Last updated:** 2026-04-02

## Interfaces

```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536
    inet 127.0.0.1/8 scope host lo
    inet6 ::1/128 scope host noprefixroute

2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500
    inet 178.104.28.233/32 metric 100 scope global dynamic eth0
    inet6 2a01:4f8:1c1b:e5ef::1/64 scope global
    inet6 fe80::9000:7ff:fe7d:9701/64 scope link
```

## IP Addresses

| Interface  | IP Address                  | Type       |
|------------|-----------------------------|------------|
| eth0       | 178.104.28.233/32           | DHCP       |
| eth0       | 2a01:4f8:1c1b:e5ef::1/64   | Static v6  |

## Listening Ports

| Port   | Process          | Purpose              | Exposed to       |
|--------|------------------|----------------------|-------------------|
| 22     | sshd             | SSH access           | Public (0.0.0.0)  |
| 53     | AdGuard Home     | DNS service          | Public (0.0.0.0)  |
| 80     | Caddy            | HTTP redirect        | Public (0.0.0.0)  |
| 443    | Caddy            | HTTPS reverse proxy  | Public (0.0.0.0)  |
| 2019   | Caddy admin      | Caddy admin API      | localhost only    |
| 7080   | AdGuard Home     | Web UI               | localhost only    |
| 9090   | Cockpit          | System management UI | localhost only    |
| 53     | systemd-resolved | DNS stub resolver    | localhost only    |

> Run `ss -tlnp` to refresh this table.

## Firewall Rules

```
No firewall configured (ufw not active, iptables/nftables not loaded)
```

## DNS

| Setting          | Value                                              |
|------------------|----------------------------------------------------|
| Nameservers      | 2a01:4ff:ff00::add:2, 2a01:4ff:ff00::add:1, 185.12.64.1, 185.12.64.2 |
| Search domain    | (none)                                             |
| Resolver         | systemd-resolved (stub mode)                       |

## Tailscale

Not installed.

## Routing

```
default via 172.31.1.1 dev eth0 proto dhcp src 178.104.28.233 metric 100
172.31.1.1 dev eth0 proto dhcp scope link src 178.104.28.233 metric 100
185.12.64.1 via 172.31.1.1 dev eth0 proto dhcp src 178.104.28.233 metric 100
185.12.64.2 via 172.31.1.1 dev eth0 proto dhcp src 178.104.28.233 metric 100
```

## Reverse Proxy (Caddy)

Not installed.
