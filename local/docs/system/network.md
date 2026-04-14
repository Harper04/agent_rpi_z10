# Network Configuration

> **Last updated:** TODO

## Interfaces

```
# Output of ip addr
TODO
```

## IP Addresses

| Interface  | IP Address       | Type       |
|------------|------------------|------------|
| eth0       | TODO             | Static/DHCP|
| tailscale0 | TODO             | Tailscale  |

## Listening Ports

| Port   | Process          | Purpose              | Exposed to       |
|--------|------------------|----------------------|-------------------|
| 22     | sshd             | SSH access           | Tailscale only    |

> Run `ss -tlnp` to refresh this table.

## Firewall Rules

```
# ufw status / iptables -L / nftables
TODO
```

## DNS

| Setting          | Value                          |
|------------------|--------------------------------|
| Nameservers      | TODO                           |
| Search domain    | TODO                           |
| MagicDNS         | TODO (enabled/disabled)        |

## Tailscale

| Setting          | Value                          |
|------------------|--------------------------------|
| Node name        | TODO                           |
| Tailscale IP     | TODO                           |
| Advertised routes| TODO                           |
| Exit node        | TODO (yes/no)                  |
| MagicDNS         | TODO                           |

## Routing

```
# Output of ip route
TODO
```

## Reverse Proxy (Caddy)

| Domain             | Upstream              | TLS        |
|--------------------|-----------------------|------------|
| TODO               | TODO                  | ACME / manual |
