/**
 * sub-limits - Display usage limits for all authenticated providers
 *
 * Requires: pi-sub-core extension installed and running
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

// Types from sub-core
type StatusIndicator = "none" | "minor" | "major" | "critical" | "maintenance" | "unknown";

interface ProviderStatus {
  indicator: StatusIndicator;
  description?: string;
}

interface RateWindow {
  label: string;
  usedPercent: number;
  resetDescription?: string;
  resetAt?: string;
}

interface UsageError {
  code: string;
  message: string;
  httpStatus?: number;
}

interface UsageSnapshot {
  provider: string;
  displayName: string;
  windows: RateWindow[];
  extraUsageEnabled?: boolean;
  fiveHourUsage?: number;
  error?: UsageError;
  status?: ProviderStatus;
  requestsSummary?: string;
  requestsRemaining?: number;
  requestsEntitlement?: number;
}

interface ProviderUsageEntry {
  provider: string;
  usage?: UsageSnapshot;
}

type SubCoreEntriesRequest = {
  type: "entries";
  force?: boolean;
  reply: (payload: { entries: ProviderUsageEntry[] }) => void;
};

export default function subLimitsExtension(pi: ExtensionAPI): void {
  pi.registerCommand("limits", {
    description: "Show usage limits for all authenticated providers (via sub-core)",
    handler: async (_args: string[], ctx: any) => {
      await showLimits(pi, ctx);
    },
  });
}

async function showLimits(pi: ExtensionAPI, ctx: any): Promise<void> {
  const entries = await fetchUsageEntries(pi, ctx);

  if (!entries) {
    return;
  }

  if (entries.length === 0) {
    ctx.ui.notify(
      "No providers found.\nMake sure sub-core is installed and auth.json is configured.",
      "warning"
    );
    return;
  }

  const output = formatUsageReport(entries);
  ctx.ui.notify(output, "info");
}

function formatUsageReport(entries: ProviderUsageEntry[]): string {
  const lines: string[] = ["Provider Usage Limits", "─".repeat(40)];

  for (const entry of entries) {
    const usage = entry.usage;

    if (!usage) {
      const name = entry.provider.charAt(0).toUpperCase() + entry.provider.slice(1);
      lines.push(`\n${name}: No credentials`);
      continue;
    }

    const statusIcon = getStatusIcon(usage.status?.indicator);
    const providerName = usage.displayName || entry.provider;
    lines.push(`\n${statusIcon} ${providerName}`);

    if (usage.error) {
      lines.push(`  ⚠ ${formatError(usage.error)}`);
      continue;
    }

    // Rate windows
    for (const window of usage.windows) {
      const bar = renderProgressBar(window.usedPercent);
      const pct = `${Math.round(window.usedPercent)}%`;
      let line = `  ${window.label}: ${bar} ${pct}`;
      if (window.resetDescription) {
        line += ` (${window.resetDescription})`;
      }
      lines.push(line);
    }

    // Extra info
    if (usage.requestsSummary) {
      lines.push(`  ${usage.requestsSummary}`);
    }

    if (usage.fiveHourUsage !== undefined) {
      lines.push(`  5h Usage: $${usage.fiveHourUsage.toFixed(2)}`);
    }

    if (usage.extraUsageEnabled !== undefined) {
      const status = usage.extraUsageEnabled ? "On" : "Off";
      lines.push(`  Extra Usage: ${status}`);
    }
  }

  return lines.join("\n");
}

function renderProgressBar(percent: number): string {
  const width = 15;
  const filled = Math.round((percent / 100) * width);
  const empty = width - filled;
  return "█".repeat(filled) + "░".repeat(empty);
}

function getStatusIcon(indicator?: StatusIndicator): string {
  switch (indicator) {
    case "none":
      return "●"; // green/ok
    case "minor":
      return "◐"; // partial issue
    case "major":
    case "critical":
      return "○"; // major issue
    case "maintenance":
      return "◑"; // maintenance
    default:
      return "●";
  }
}

function formatError(error: UsageError): string {
  switch (error.code) {
    case "NO_CREDENTIALS":
      return "No credentials configured";
    case "NO_CLI":
      return "Required CLI tool not found";
    case "NOT_LOGGED_IN":
      return "Not logged in";
    case "FETCH_FAILED":
      return "Failed to fetch usage data";
    case "HTTP_ERROR":
      return `API error (${error.httpStatus ?? "unknown"})`;
    case "API_ERROR":
      return "API returned an error";
    case "TIMEOUT":
      return "Request timed out";
    default:
      return error.message || "Unknown error";
  }
}

function isSubCoreAvailable(pi: ExtensionAPI): boolean {
  try {
    const events = pi.events as { listenerCount?: (event: string) => number };
    if (typeof events.listenerCount === "function") {
      return events.listenerCount("sub-core:request") > 0;
    }
    return true;
  } catch {
    return true;
  }
}

async function fetchUsageEntries(pi: ExtensionAPI, ctx: any): Promise<ProviderUsageEntry[] | null> {
  if (!isSubCoreAvailable(pi)) {
    ctx.ui.notify(
      "sub-core extension not loaded.\n\nInstall: pi install npm:@marckrenn/pi-sub-core\nThen run: /reload",
      "warning"
    );
    return null;
  }

  return new Promise((resolve) => {
    let responded = false;
    const timeout = setTimeout(() => {
      if (!responded) {
        responded = true;
        ctx.ui.notify("sub-core timed out.\nTry again or check provider credentials.", "warning");
        resolve(null);
      }
    }, 5000);

    const request: SubCoreEntriesRequest = {
      type: "entries",
      force: true,
      reply: (payload) => {
        if (!responded) {
          responded = true;
          clearTimeout(timeout);
          resolve(payload.entries ?? []);
        }
      },
    };

    try {
      pi.events.emit("sub-core:request", request);
    } catch (err) {
      if (!responded) {
        responded = true;
        clearTimeout(timeout);
        ctx.ui.notify(`Error: ${err}`, "error");
        resolve(null);
      }
    }
  });
}
