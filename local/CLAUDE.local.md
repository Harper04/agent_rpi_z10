# Machine: min-core

> This file is machine-specific and NEVER pushed to the shared template upstream.
> It is auto-populated by `./setup.sh` and updated by agents during operation.

## Machine Identity

| Key              | Value                          |
|------------------|--------------------------------|
| Hostname         | `min-core`                     |
| OS               | Ubuntu 24.04.3 LTS             |
| Kernel           | `6.8.0-90-generic`             |
| Architecture     | `x86_64`                       |
| Virtualization   | KVM (Hetzner vServer)          |
| CPU              | Intel Xeon (Skylake) 2x @ 2.1GHz |
| RAM              | 3.7 GiB                        |
| Disk             | 38.1 GB (/dev/sda, ext4)       |
| Primary IP       | `178.104.28.233`               |
| IPv6             | `2a01:4f8:1c1b:e5ef::1`       |
| Tailscale IP     | `not configured`               |
| SSH Port         | `22`                           |
| Managed by       | tom@altow.de                   |
| Purpose          | Minimal core server (Hetzner)  |
| Git origin       | `https://github.com/harper04/agent_mini_core.git` |
| Git upstream     | `https://github.com/harper04/agent-sysadmin.git`  |

## Installed Applications

> List of applications managed on THIS machine.
> Each should have a corresponding doc in `local/docs/apps/`.

| App              | Agent        | Status      |
|------------------|--------------|-------------|
| route53-dns      | orchestrator | configured  |

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
| (none) | —           | —                      |

### Local Agents

> Agents in `local/agents/` override or extend shared agents.

None yet.

## Secrets Reference

> DO NOT put actual secrets here. Just document what secrets exist and where.

| Secret              | Location          | Purpose                |
|---------------------|-------------------|------------------------|
| Telegram Bot Token  | `local/.env`      | Agent notifications    |
| Telegram Chat ID    | `local/.env`      | Operator chat          |
| GitHub PAT          | `local/.env`      | Git push/pull          |

## Notes

> Free-form notes specific to this machine.

- Fresh Hetzner vServer, minimal Ubuntu 24.04 cloud image
- No firewall configured yet (ufw installed but inactive)
- No application services deployed yet
- Unattended upgrades enabled for security patches
- Swap: disabled (0B)
