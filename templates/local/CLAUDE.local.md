# Machine: TODO-HOSTNAME

> This file is machine-specific and NEVER pushed to the shared template upstream.
> It is auto-populated by `./setup.sh` and updated by agents during operation.

## Machine Identity

| Key              | Value                          |
|------------------|--------------------------------|
| Hostname         | `TODO`                         |
| OS               | Ubuntu Server 24.04 LTS        |
| Architecture     | `TODO` (aarch64 / x86_64)     |
| Primary IP       | `TODO`                         |
| Tailscale IP     | `TODO`                         |
| SSH Port         | `TODO`                         |
| Managed by       | tom@altow.de                   |
| Purpose          | `TODO`                         |
| Git origin       | `TODO`                         |
| Git upstream     | `TODO`                         |

## Installed Applications

> List of applications managed on THIS machine.
> Each should have a corresponding doc in `local/docs/apps/`.

| App              | Agent        | Status  |
|------------------|--------------|---------|
| TODO             | TODO         | TODO    |

## Local Overrides

> Machine-specific deviations from the shared agent definitions.

### Held Packages
```
# apt-mark showhold output
TODO
```

### Custom Ports
| Port   | Service     | Reason for non-default |
|--------|-------------|------------------------|
| TODO   | TODO        | TODO                   |

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
