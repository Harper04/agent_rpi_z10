# Machine: ziegeleiweg-pi

> This file is machine-specific and NEVER pushed to the shared template upstream.
> It is auto-populated by `./setup.sh` and updated by agents during operation.

## Machine Identity

| Key              | Value                          |
|------------------|--------------------------------|
| Hostname         | `ziegeleiweg-pi`                         |
| OS               | Ubuntu 25.10        |
| Architecture     | `aarch64`     |
| Primary IP       | `192.168.2.32` (DHCP, may change)       |
| Tailscale IP     | `not configured`                          |
| Bridge IP (br0)  | `192.168.2.32`                            |
| SSH Port         | `22`                         |
| Managed by       | tom@altow.de                   |
| Purpose          | `TODO`                         |
| Git origin       | `https://github.com/harper04/agent_rpi_z10.git` |
| Git upstream     | `https://github.com/harper04/agent-sysadmin.git` |

## Installed Applications

> List of applications managed on THIS machine.
> Each should have a corresponding doc in `local/docs/apps/`.

| App              | Agent        | Status  |
|------------------|--------------|---------|
| ZeroTier         | orchestrator | ✅ Running |
| UniFi OS Server  | orchestrator | ✅ Running |
| Home Assistant   | orchestrator | ✅ Running (KVM) |
| Route53 DNS      | orchestrator | ✅ Running |

## Local Overrides

> Machine-specific deviations from the shared agent definitions.

### Held Packages
```
# apt-mark showhold output
TODO
```

### Custom Ports
| Port   | Service              | Reason for non-default              |
|--------|----------------------|-------------------------------------|
| 11443  | UniFi OS Web UI      | Podman container (HTTPS, self-signed)|
| 8123   | Home Assistant       | KVM guest at 192.168.2.174          |
| 7080   | AdGuard Home         | Default AdGuard HTTP port           |

### Local Agents

> Agents in `local/agents/` override or extend shared agents.

None yet.

## Secrets Reference

> DO NOT put actual secrets here. Just document what secrets exist and where.

| Secret              | Location          | Purpose                |
|---------------------|-------------------|------------------------|
| Telegram Bot Token  | `local/.env`      | Agent notifications    |
| Telegram Chat ID    | `local/.env`      | Operator chat          |
| AWS Access Key      | `local/.env`      | Route53 DNS management |
| AWS Secret Key      | `local/.env`      | Route53 DNS management |
| HA API Token        | `local/.env`      | Home Assistant REST API |

## Notes

> Free-form notes specific to this machine.
