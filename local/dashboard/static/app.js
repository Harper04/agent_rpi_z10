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

    /**
     * Build a compact DNS tree from flat records.
     * Returns flat rows with depth for indentation.
     *
     * Each row: { label, fqdn, depth, types[], records[], expanded }
     *   - label: display name ("myhost", "zt > z10", "@ (root)")
     *   - types: unique record types for inline badges
     *   - records: full record objects for expanded view
     *   - expanded: whether values are shown
     *
     * Single-child chains are collapsed: zt > z10 becomes one row.
     */
    buildDnsRows(records, zoneName) {
      if (!records) return [];

      // Step 1: build raw tree
      const root = { label: zoneName, children: {}, records: [] };

      for (const rec of records) {
        const sub = rec.name === zoneName ? "" : rec.name.replace("." + zoneName, "");
        if (!sub) { root.records.push(rec); continue; }

        const parts = sub.split(".").reverse();
        let node = root;
        for (const part of parts) {
          if (!node.children[part]) {
            node.children[part] = { label: part, children: {}, records: [] };
          }
          node = node.children[part];
        }
        node.records.push(rec);
      }

      // Step 2: flatten to rows, collapsing single-child chains
      const rows = [];

      const flatten = (node, depth, isRoot) => {
        const kids = Object.values(node.children).sort((a, b) => a.label.localeCompare(b.label));

        // Add this node's own records as a row
        if (node.records.length > 0) {
          const label = isRoot ? "@ (root)" : node.label;
          const fqdn = node.records[0]?.name || zoneName;
          const types = [...new Set(node.records.map(r => r.type))];
          // Merge A+AAAA display
          const mergedTypes = types.filter(t => t !== "AAAA" || !types.includes("A"))
            .map(t => t === "A" && types.includes("AAAA") ? "A/AAAA" : t);
          rows.push({ label, fqdn, depth, types: mergedTypes, records: node.records, expanded: false });
        }

        // Process children
        for (const kid of kids) {
          // Collapse single-child chains: if kid has no records and exactly 1 child,
          // merge labels with " > "
          let current = kid;
          let chainLabel = kid.label;
          while (current.records.length === 0 && Object.keys(current.children).length === 1) {
            const only = Object.values(current.children)[0];
            chainLabel += " > " + only.label;
            current = only;
          }

          if (current !== kid) {
            // Collapsed chain — use the merged label and process current's content
            const mergedNode = { ...current, label: chainLabel };
            flatten(mergedNode, depth + 1, false);
          } else {
            // Normal node with records or multiple children
            const hasKids = Object.keys(kid.children).length > 0;
            if (hasKids && kid.records.length > 0) {
              // Branch node with own records — show as parent row
              const fqdn = kid.records[0]?.name || "";
              const types = [...new Set(kid.records.map(r => r.type))];
              const mergedTypes = types.filter(t => t !== "AAAA" || !types.includes("A"))
                .map(t => t === "A" && types.includes("AAAA") ? "A/AAAA" : t);
              rows.push({ label: kid.label, fqdn, depth: depth + 1, types: mergedTypes, records: kid.records, expanded: false, hasChildren: true });
              // Then recurse children only
              const grandkids = Object.values(kid.children).sort((a, b) => a.label.localeCompare(b.label));
              for (const gk of grandkids) flatten(gk, depth + 2, false);
            } else if (hasKids) {
              // Branch node, no own records — just recurse
              flatten(kid, depth + 1, false);
            } else {
              // Leaf node
              flatten(kid, depth + 1, false);
            }
          }
        }
      };

      flatten(root, 0, true);
      return rows;
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
