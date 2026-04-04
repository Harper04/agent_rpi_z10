/**
 * Dashboard frontend — Alpine.js data component
 * Generic: pulls hostname/subtitle from /api/config
 */
function dashboard() {
  return {
    // State
    config: { hostname: "", subtitle: "" },
    health: null,
    services: [],
    agentStatus: "unknown",
    agentRestarting: false,
    agentMsg: "",
    dnsTree: {},
    dnsLoading: true,
    dnsError: "",
    ztMembers: [],
    ztLoading: true,
    ztError: "",
    openZones: {},
    lastRefresh: "",

    // Computed-like
    get memPercent() {
      if (!this.health?.memory) return 0;
      return Math.round(
        (this.health.memory.used / this.health.memory.total) * 100
      );
    },
    get diskPercent() {
      if (!this.health?.disk) return 0;
      return Math.round(
        (this.health.disk.used / this.health.disk.total) * 100
      );
    },

    // Init
    async init() {
      // Fire all requests in parallel
      await Promise.allSettled([
        this.fetchConfig(),
        this.fetchHealth(),
        this.fetchServices(),
        this.fetchAgentStatus(),
        this.fetchDns(),
        this.fetchZerotier(),
      ]);
      this.lastRefresh = new Date().toLocaleTimeString();

      // Update page title
      if (this.config.hostname) {
        document.title = `${this.config.hostname} — Dashboard`;
      }

      // Auto-refresh health every 30s
      setInterval(() => this.fetchHealth(), 30000);
      // Auto-refresh agent status every 15s
      setInterval(() => this.fetchAgentStatus(), 15000);
    },

    // API calls
    async fetchConfig() {
      try {
        const r = await fetch("/api/config");
        this.config = await r.json();
      } catch (e) {
        console.error("Config fetch failed:", e);
      }
    },

    async fetchHealth() {
      try {
        const r = await fetch("/api/health");
        this.health = await r.json();
        this.lastRefresh = new Date().toLocaleTimeString();
      } catch (e) {
        console.error("Health fetch failed:", e);
      }
    },

    async fetchServices() {
      try {
        const r = await fetch("/api/services");
        this.services = await r.json();
      } catch (e) {
        console.error("Services fetch failed:", e);
      }
    },

    async fetchAgentStatus() {
      try {
        const r = await fetch("/api/agent/status");
        const data = await r.json();
        this.agentStatus = data.active;
      } catch (e) {
        this.agentStatus = "unknown";
      }
    },

    async fetchDns() {
      this.dnsLoading = true;
      this.dnsError = "";
      try {
        const r = await fetch("/api/dns");
        const data = await r.json();
        if (data.error) {
          this.dnsError = data.error;
        } else {
          this.dnsTree = data;
          // Auto-open first zone
          const firstZone = Object.keys(data)[0];
          if (firstZone) this.openZones[firstZone] = true;
        }
      } catch (e) {
        this.dnsError = "Failed to load DNS records";
      }
      this.dnsLoading = false;
    },

    async fetchZerotier() {
      this.ztLoading = true;
      this.ztError = "";
      try {
        const r = await fetch("/api/zerotier");
        const data = await r.json();
        if (data.error) {
          this.ztError = data.error;
        } else if (Array.isArray(data)) {
          this.ztMembers = data.sort((a, b) =>
            (b.online ? 1 : 0) - (a.online ? 1 : 0) || a.name.localeCompare(b.name)
          );
        }
      } catch (e) {
        this.ztError = "Failed to load ZeroTier members";
      }
      this.ztLoading = false;
    },

    async restartAgent() {
      if (!confirm("Restart sysadmin-agent? The dashboard may briefly disconnect.")) return;
      this.agentRestarting = true;
      this.agentMsg = "";
      try {
        const r = await fetch("/api/agent/restart", { method: "POST" });
        const data = await r.json();
        if (data.success) {
          this.agentMsg = "Agent restarted successfully. Status: " + data.status;
          this.agentStatus = data.status;
        } else {
          this.agentMsg = "Restart failed: " + data.error;
        }
      } catch (e) {
        this.agentMsg = "Restart request failed — agent may be restarting.";
      }
      this.agentRestarting = false;
      // Re-check status after a moment
      setTimeout(() => this.fetchAgentStatus(), 3000);
    },

    // Helpers
    toggleZone(name) {
      this.openZones[name] = !this.openZones[name];
    },

    groupRecords(records, zoneName) {
      if (!records) return [];

      // Group by host prefix (subdomain)
      const groups = {};
      for (const rec of records) {
        // Determine the group label
        let label;
        if (rec.name === zoneName) {
          label = "@ (root)";
        } else {
          // Strip the zone suffix to get the subdomain
          const sub = rec.name.replace("." + zoneName, "").replace(zoneName, "");
          label = sub || "@ (root)";
        }

        if (!groups[label]) {
          groups[label] = { label, records: [], open: label === "@ (root)" };
        }
        groups[label].records.push(rec);
      }

      // Sort: root first, then alphabetically
      return Object.values(groups).sort((a, b) => {
        if (a.label === "@ (root)") return -1;
        if (b.label === "@ (root)") return 1;
        return a.label.localeCompare(b.label);
      });
    },

    formatBytes(bytes) {
      if (!bytes) return "0 B";
      const units = ["B", "KB", "MB", "GB", "TB"];
      let i = 0;
      let val = bytes;
      while (val >= 1024 && i < units.length - 1) {
        val /= 1024;
        i++;
      }
      return val.toFixed(1) + " " + units[i];
    },
  };
}
