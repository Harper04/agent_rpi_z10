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
| Tailscale IP     | `not configured`                         |
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
