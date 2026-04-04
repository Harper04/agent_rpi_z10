# Machine Conventions — mini-core

> Machine-specific conventions that extend `docs/conventions.md`.
> These apply ONLY to this machine and are NOT pushed upstream.

## zerotier-not-tailscale

**Scope:** Any agent configuring VPN or mesh networking
**Convention:** This machine uses ZeroTier, not Tailscale. The tailscale agent is not applicable here. ZeroTier API credentials are in `local/.env` (`ZEROTIER_API_KEY`, `ZEROTIER_NETWORK_ID`).
**Reason:** Operator's network uses ZeroTier Central.
**Added:** 2026-04-04
**Owner:** orchestrator

## dashboard-port-3100

**Scope:** Any agent allocating ports or modifying the dashboard
**Convention:** The system dashboard runs on `localhost:3100` (Bun). Caddy proxies `mini-core.tiny-systems.eu` to it. The service is `mini-core-dashboard.service`. Source lives in `local/dashboard/`.
**Reason:** Avoid port conflicts; know where to find dashboard code.
**Added:** 2026-04-04
**Owner:** orchestrator
