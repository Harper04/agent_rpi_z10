# Machine: strandstr-pi

> This file is machine-specific and NEVER pushed to the shared template upstream.
> It is auto-populated by `./setup.sh` and updated by agents during operation.

## Machine Identity

| Key              | Value                          |
|------------------|--------------------------------|
| Hostname         | `strandstr-pi`                         |
| OS               | Ubuntu 25.10 (kernel 6.17.0-1008-raspi) |
| Architecture     | `aarch64`     |
| Primary IP       | `192.168.2.93` (static, locked)         |
| ZeroTier IP      | `192.168.195.217` (ztrta4apg4, net 8286ac0e476c329b) |
| ZT domain        | `s85.zt.tiny-systems.eu`                 |
| LAN domain       | `s85.local.tiny-systems.eu`              |
| SSH Port         | `22`                         |
| Managed by       | tom@altow.de                   |
| Purpose          | Raspberry Pi 5 home server     |
| Git origin       | `https://github.com/Harper04/agent_rpi_s85.git`                         |
| Git upstream     | `https://github.com/harper04/agent-sysadmin.git`                         |

## Installed Applications

> List of applications managed on THIS machine.
> Each should have a corresponding doc in `local/docs/apps/`.

| App              | Agent        | Status  |
|------------------|--------------|---------|
| sysadmin-agent   | orchestrator | active  |
| zerotier-one     | orchestrator | active  |
| aws-cli          | orchestrator | active  |
| caddy            | caddy        | active  |
| dashboard        | orchestrator | active  |
| libvirt/KVM      | kvm          | active  |
| home-assistant   | kvm          | active (VM @ 192.168.2.182) |
| unifi-os-server  | docker       | active (podman, port 11443) |
| adguard-home     | docker       | active (podman, port 53 DNS + 3000 web UI) |

## Local Overrides

> Machine-specific deviations from the shared agent definitions.

### Held Packages
```
# apt-mark showhold output
(none)
```

### Custom Ports
| Port   | Service     | Reason for non-default |
|--------|-------------|------------------------|
| 22     | SSH         | Default                |
| 9993   | zerotier-one | ZeroTier P2P (UDP)   |
| 80     | caddy        | HTTP → HTTPS redirect |
| 443    | caddy        | HTTPS (TLS termination) |
| 3100   | dashboard    | Bun server (localhost only) |
| 11443  | uosserver    | UniFi OS HTTPS (mapped from container :443) |
| 8080   | uosserver    | UniFi device inform port |
| 8443   | uosserver    | UniFi HTTPS UI |
| 8444   | uosserver    | UniFi portal HTTPS |
| 3478   | uosserver    | STUN/UDP |
| 6789   | uosserver    | UniFi speed test |
| 53     | adguard-home | DNS (UDP+TCP, bound to 192.168.2.93 and 192.168.195.217 only) |
| 3000   | adguard-home | AdGuard Home web UI (localhost only, proxied by Caddy) |

### Local Agents

> Agents in `local/agents/` override or extend shared agents.

None yet.

## Secrets Reference

> DO NOT put actual secrets here. Just document what secrets exist and where.

| Secret              | Location          | Purpose                |
|---------------------|-------------------|------------------------|
| Telegram Bot Token  | `local/.env`      | Agent notifications    |
| Telegram Chat ID    | `local/.env`      | Operator chat          |

## Notes

> Free-form notes specific to this machine.
