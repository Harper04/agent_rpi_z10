/**
 * Sysadmin Dashboard — Bun HTTP Server
 *
 * Generic dashboard for sysadmin-agent managed machines.
 * Serves static frontend + JSON API endpoints.
 * Auth is handled by Caddy (forward_auth) — we trust all requests that reach us.
 *
 * Configuration via environment variables:
 *   DASHBOARD_PORT          — Listen port (default: 3100)
 *   DASHBOARD_SUBTITLE      — Subtitle shown in header (default: "Managed Server")
 *   DNS_RECORD_FILTERS      — Comma-separated substrings to filter from DNS records
 *                              (default: "\\052,_owner")
 *   CADDY_SITES_DIR         — Path to Caddy site configs (default: /etc/caddy/sites)
 *   ZEROTIER_API_KEY        — ZeroTier Central API token (optional)
 *   ZEROTIER_NETWORK_ID     — ZeroTier network ID (optional)
 *   AWS_ACCESS_KEY_ID       — For Route53 DNS (optional, uses aws cli credentials)
 *   AWS_SECRET_ACCESS_KEY   — For Route53 DNS (optional)
 *
 * API:
 *   GET  /api/config         — dashboard config (hostname, subtitle)
 *   GET  /api/services       — web services on this host (auto-discovered from Caddy)
 *   GET  /api/dns            — Route53 hosted zones + records (tree)
 *   GET  /api/zerotier       — ZeroTier network members
 *   GET  /api/health         — basic system health
 *   GET  /api/agent/status   — sysadmin-agent systemd state
 *   POST /api/agent/restart  — restart sysadmin-agent.service
 */

import { serve, file } from "bun";
import { join } from "path";
import { readdir, readFile } from "fs/promises";

const PORT = Number(process.env.DASHBOARD_PORT) || 3100;
const STATIC_DIR = join(import.meta.dir, "static");
const CADDY_SITES_DIR = process.env.CADDY_SITES_DIR || "/etc/caddy/sites";
const SUBTITLE = process.env.DASHBOARD_SUBTITLE || "Managed Server";

// DNS record filters: comma-separated substrings to exclude
const DNS_FILTERS = (process.env.DNS_RECORD_FILTERS || "\\052,_owner")
  .split(",")
  .map((f) => f.trim())
  .filter(Boolean);

// ── Service discovery from Caddy site files ───────────────────────────

interface Service {
  name: string;
  url: string;
  icon: string;
  description: string;
}

let cachedServices: Service[] = [];
let servicesCacheTime = 0;
const SERVICES_CACHE_TTL = 60_000; // 60 seconds

async function discoverServices(): Promise<Service[]> {
  const now = Date.now();
  if (cachedServices.length && now - servicesCacheTime < SERVICES_CACHE_TTL) {
    return cachedServices;
  }

  try {
    const files = await readdir(CADDY_SITES_DIR);
    const caddyFiles = files.filter((f) => f.endsWith(".caddy"));
    const services: Service[] = [];

    for (const filename of caddyFiles) {
      const content = await readFile(join(CADDY_SITES_DIR, filename), "utf-8");

      // Parse @ annotations from comments
      const annotations: Record<string, string> = {};
      for (const line of content.split("\n")) {
        const match = line.match(/^#\s*@(\w+)\s+(.+)$/);
        if (match) annotations[match[1]] = match[2].trim();
      }

      // Skip if not marked for dashboard
      if (annotations.dashboard !== "true") continue;

      // Extract domain from first site block: "domain.com {" or "domain1.com, domain2.com {"
      const domainMatch = content.match(/^([a-zA-Z0-9][\w.-]+\.[a-z]{2,})[\s,{]/m);
      if (!domainMatch) continue;

      const domain = domainMatch[1];

      services.push({
        name: annotations.name || domain,
        url: `https://${domain}/`,
        icon: annotations.icon || "las la-globe",
        description: annotations.description || "",
      });
    }

    // Sort: Dashboard first, then alphabetically
    services.sort((a, b) => {
      if (a.name === "Dashboard") return -1;
      if (b.name === "Dashboard") return 1;
      return a.name.localeCompare(b.name);
    });

    cachedServices = services;
    servicesCacheTime = now;
    return services;
  } catch (e: any) {
    console.error("Service discovery failed:", e.message);
    return cachedServices; // return stale cache on error
  }
}

// ── Helpers ────────────────────────────────────────────────────────────

async function run(cmd: string[]): Promise<string> {
  const proc = Bun.spawn(cmd, { stdout: "pipe", stderr: "pipe" });
  const out = await new Response(proc.stdout).text();
  await proc.exited;
  return out.trim();
}

function jsonResponse(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// ── API: Config ───────────────────────────────────────────────────────

let cachedHostname: string | null = null;

async function getConfig() {
  if (!cachedHostname) {
    cachedHostname = await run(["hostname"]);
  }
  return {
    hostname: cachedHostname,
    subtitle: SUBTITLE,
  };
}

// ── API: Health ────────────────────────────────────────────────────────

async function getHealth() {
  const [hostname, uptime, memRaw, dfRaw, loadRaw] = await Promise.all([
    run(["hostname"]),
    run(["uptime", "-p"]),
    run(["free", "-b"]),
    run(["df", "-B1", "/"]),
    run(["cat", "/proc/loadavg"]),
  ]);

  // Cache hostname from health check
  cachedHostname = hostname;

  // Parse memory
  const memLine = memRaw.split("\n").find((l) => l.startsWith("Mem:"));
  const memParts = memLine?.split(/\s+/) || [];
  const memTotal = Number(memParts[1]) || 0;
  const memUsed = Number(memParts[2]) || 0;

  // Parse disk
  const dfLine = dfRaw.split("\n")[1];
  const dfParts = dfLine?.split(/\s+/) || [];
  const diskTotal = Number(dfParts[1]) || 0;
  const diskUsed = Number(dfParts[2]) || 0;

  // Parse load
  const loadParts = loadRaw.split(/\s+/);

  return {
    hostname,
    uptime,
    memory: { total: memTotal, used: memUsed },
    disk: { total: diskTotal, used: diskUsed },
    load: {
      "1m": Number(loadParts[0]),
      "5m": Number(loadParts[1]),
      "15m": Number(loadParts[2]),
    },
  };
}

// ── API: Route53 DNS ───────────────────────────────────────────────────

async function getDnsRecords() {
  try {
    // List hosted zones
    const zonesRaw = await run([
      "aws", "route53", "list-hosted-zones", "--output", "json",
    ]);
    const zones = JSON.parse(zonesRaw).HostedZones || [];

    const tree: Record<string, any> = {};

    for (const zone of zones) {
      const zoneId = zone.Id.replace("/hostedzone/", "");
      const zoneName = zone.Name.replace(/\.$/, "");

      // Get all records for this zone
      const recordsRaw = await run([
        "aws", "route53", "list-resource-record-sets",
        "--hosted-zone-id", zoneId,
        "--output", "json",
      ]);
      const recordSets = JSON.parse(recordsRaw).ResourceRecordSets || [];

      const records = recordSets
        .filter((r: any) => {
          const name = r.Name.replace(/\.$/, "");
          // Apply configurable filters
          for (const filter of DNS_FILTERS) {
            if (name.includes(filter)) return false;
          }
          // Also filter wildcard records shown as "*"
          if (name.startsWith("*")) return false;
          return true;
        })
        .map((r: any) => ({
          name: r.Name.replace(/\.$/, ""),
          type: r.Type,
          ttl: r.TTL,
          values: r.AliasTarget
            ? [`ALIAS → ${r.AliasTarget.DNSName.replace(/\.$/, "")}`]
            : (r.ResourceRecords || []).map((rr: any) => rr.Value),
        }));

      tree[zoneName] = {
        zoneId,
        recordCount: records.length,
        isPrivate: zone.Config?.PrivateZone || false,
        records,
      };
    }

    return tree;
  } catch (e: any) {
    return { error: e.message };
  }
}

// ── API: ZeroTier ──────────────────────────────────────────────────────

async function getZerotierMembers() {
  const apiKey = process.env.ZEROTIER_API_KEY;
  const networkId = process.env.ZEROTIER_NETWORK_ID;

  if (!apiKey || !networkId) {
    return { error: "ZeroTier not configured. Set ZEROTIER_API_KEY and ZEROTIER_NETWORK_ID in local/.env" };
  }

  try {
    const resp = await fetch(
      `https://api.zerotier.com/api/v1/network/${networkId}/member`,
      { headers: { Authorization: `token ${apiKey}` } }
    );
    if (!resp.ok) throw new Error(`ZeroTier API: ${resp.status}`);
    const members = await resp.json();

    const now = Date.now();
    return members.map((m: any) => {
      // Derive online status: seen within the last 5 minutes
      const lastSeen = m.lastSeen || 0;
      const online = m.online ?? (now - lastSeen < 5 * 60 * 1000);
      return {
        name: m.name || m.description || m.nodeId,
        nodeId: m.nodeId,
        online,
        authorized: m.config?.authorized,
        ips: m.config?.ipAssignments || [],
        lastSeen,
      };
    });
  } catch (e: any) {
    return { error: e.message };
  }
}

// ── API: Agent restart ─────────────────────────────────────────────────

async function restartAgent() {
  try {
    const proc = Bun.spawn(
      ["sudo", "systemctl", "restart", "sysadmin-agent.service"],
      { stdout: "pipe", stderr: "pipe" }
    );
    const stderr = await new Response(proc.stderr).text();
    const code = await proc.exited;

    if (code !== 0) {
      return { success: false, error: stderr.trim() };
    }

    // Brief pause to let it start
    await Bun.sleep(1000);

    const status = await run([
      "systemctl", "is-active", "sysadmin-agent.service",
    ]);

    return { success: true, status };
  } catch (e: any) {
    return { success: false, error: e.message };
  }
}

// ── API: Agent status ──────────────────────────────────────────────────

async function getAgentStatus() {
  try {
    const [active, sub] = await Promise.all([
      run(["systemctl", "is-active", "sysadmin-agent.service"]),
      run(["systemctl", "show", "sysadmin-agent.service", "--property=SubState", "--value"]),
    ]);
    return { active, sub };
  } catch {
    return { active: "unknown", sub: "unknown" };
  }
}

// ── Static file serving ────────────────────────────────────────────────

async function serveStatic(path: string): Promise<Response> {
  // Default to index.html
  if (path === "/" || path === "") path = "/index.html";

  const filePath = join(STATIC_DIR, path);

  // Security: prevent directory traversal
  if (!filePath.startsWith(STATIC_DIR)) {
    return new Response("Forbidden", { status: 403 });
  }

  const f = file(filePath);
  if (await f.exists()) {
    return new Response(f);
  }

  // SPA fallback
  return new Response(file(join(STATIC_DIR, "index.html")));
}

// ── Router ─────────────────────────────────────────────────────────────

serve({
  port: PORT,
  async fetch(req) {
    const url = new URL(req.url);
    const path = url.pathname;

    // API routes
    if (path === "/api/config") {
      return jsonResponse(await getConfig());
    }
    if (path === "/api/services") {
      return jsonResponse(await discoverServices());
    }
    if (path === "/api/health") {
      return jsonResponse(await getHealth());
    }
    if (path === "/api/dns") {
      return jsonResponse(await getDnsRecords());
    }
    if (path === "/api/zerotier") {
      return jsonResponse(await getZerotierMembers());
    }
    if (path === "/api/agent/status") {
      return jsonResponse(await getAgentStatus());
    }
    if (path === "/api/agent/restart" && req.method === "POST") {
      return jsonResponse(await restartAgent());
    }

    // Static files
    return serveStatic(path);
  },
});

console.log(`Dashboard running on http://localhost:${PORT}`);
