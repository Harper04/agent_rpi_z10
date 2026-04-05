# System Services

> **Last updated:** TODO

## Critical Services

| Service            | Status   | Enabled | Purpose                   |
|--------------------|----------|---------|---------------------------|
| sshd               | TODO     | yes     | Remote access             |
| tailscaled         | TODO     | yes     | Mesh VPN                  |

## Application Services

| Service            | Status   | Enabled | Agent       | Purpose       |
|--------------------|----------|---------|-------------|---------------|
| caddy              | TODO     | TODO    | caddy       | Reverse proxy |
| k3s                | TODO     | TODO    | k3s         | Kubernetes    |
| libvirtd           | TODO     | TODO    | kvm         | Virtualization|
| docker             | TODO     | TODO    | docker      | Containers    |

## Failed Services

```bash
# Output of systemctl --failed
TODO
```

## Timers (scheduled)

```bash
# Output of systemctl list-timers --all
TODO
```
