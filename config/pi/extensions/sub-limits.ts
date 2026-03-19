/**
 * sub-limits - Display usage limits for all authenticated providers
 *
 * Requires: pi-sub-core extension installed and running
 *
 * Extras added:
 * - /sub-pace command for CodexBar-style pace summary
 * - footer status item "sub-pace" that updates from sub-core events
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

type SubCoreUsagePayload = {
  state?: { usage?: UsageSnapshot };
};

type SubCoreCurrentRequest = {
  type?: "current";
  reply: (payload: SubCoreUsagePayload) => void;
};

type PaceStage =
  | "onTrack"
  | "slightlyAhead"
  | "ahead"
  | "farAhead"
  | "slightlyBehind"
  | "behind"
  | "farBehind";

interface PaceResult {
  windowLabel: string;
  stage: PaceStage;
  deltaPercent: number;
  expectedUsedPercent: number;
  actualUsedPercent: number;
  etaSeconds?: number;
  willLastToReset: boolean;
}

let lastCtx: any;
let currentUsage: UsageSnapshot | undefined;
let paceStatusEnabled = true;
let cleanupSubCoreListeners: (() => void) | undefined;

function clearPaceStatus(ctx: any): void {
  ctx.ui?.setStatus?.("sub-pace", "");
}

function removeSubCoreListeners(): void {
  try {
    cleanupSubCoreListeners?.();
  } catch {
    // noop
  }
  cleanupSubCoreListeners = undefined;
}

function extractUsageFromPayload(
  payload: SubCoreUsagePayload | undefined
): UsageSnapshot | undefined {
  return payload?.state?.usage;
}

function applyUsageUpdate(ctx: any, usage: UsageSnapshot | undefined): void {
  currentUsage = usage;
  if (ctx) {
    renderPaceStatus(ctx, usage);
  }
}

export default function subLimitsExtension(pi: ExtensionAPI): void {
  // Guard against leaked event listeners across /reload cycles.
  removeSubCoreListeners();

  pi.registerCommand("limits", {
    description: "Show usage limits for all authenticated providers (via sub-core)",
    handler: async (_args: string[], ctx: any) => {
      await showLimits(pi, ctx);
    },
  });

  pi.registerCommand("sub-pace", {
    description: "Show CodexBar-style pace for current provider window",
    handler: async (_args: string[], ctx: any) => {
      const usage = currentUsage ?? (await fetchCurrentUsage(pi, ctx));
      if (!usage) {
        ctx.ui?.notify?.("No current usage available from sub-core.", "warning");
        return;
      }
      const pace = computePace(usage, new Date());
      if (!pace) {
        ctx.ui?.notify?.("No pace available for this provider/window yet.", "warning");
        return;
      }
      ctx.ui?.notify?.(formatPaceDetail(usage, pace), "info");
    },
  });

  pi.registerCommand("sub-pace:toggle", {
    description: "Toggle footer pace status",
    handler: async (_args: string[], ctx: any) => {
      paceStatusEnabled = !paceStatusEnabled;
      if (!paceStatusEnabled) {
        ctx.ui?.setStatus?.("sub-pace", "");
        ctx.ui?.notify?.("sub-pace footer status: off", "info");
        return;
      }
      renderPaceStatus(ctx, currentUsage);
      ctx.ui?.notify?.("sub-pace footer status: on", "info");
    },
  });

  const handleUsagePayload = (payload: SubCoreUsagePayload) => {
    applyUsageUpdate(lastCtx, extractUsageFromPayload(payload));
  };

  pi.on("session_start", async (_event, ctx) => {
    lastCtx = ctx;
    applyUsageUpdate(ctx, await fetchCurrentUsage(pi, ctx));
  });

  pi.on("session_shutdown", async (_event, ctx) => {
    try {
      clearPaceStatus(ctx);
    } catch {
      // noop
    }
    removeSubCoreListeners();
    lastCtx = undefined;
    currentUsage = undefined;
  });

  const unsubscribeUpdate = pi.events.on("sub-core:update-current", handleUsagePayload);
  const unsubscribeReady = pi.events.on("sub-core:ready", handleUsagePayload);
  cleanupSubCoreListeners = () => {
    unsubscribeUpdate();
    unsubscribeReady();
  };
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

    const pace = computePace(usage, new Date());
    if (pace) {
      lines.push(`  ${formatPaceInline(pace)}`);
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

async function fetchCurrentUsage(pi: ExtensionAPI, ctx: any): Promise<UsageSnapshot | undefined> {
  if (!isSubCoreAvailable(pi)) return undefined;

  return new Promise((resolve) => {
    let responded = false;
    const timeout = setTimeout(() => {
      if (!responded) {
        responded = true;
        resolve(undefined);
      }
    }, 1200);

    const request: SubCoreCurrentRequest = {
      type: "current",
      reply: (payload) => {
        if (!responded) {
          responded = true;
          clearTimeout(timeout);
          resolve(payload?.state?.usage);
        }
      },
    };

    try {
      pi.events.emit("sub-core:request", request);
    } catch (err) {
      if (!responded) {
        responded = true;
        clearTimeout(timeout);
        ctx?.ui?.notify?.(`Error: ${err}`, "error");
        resolve(undefined);
      }
    }
  });
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

function renderPaceStatus(ctx: any, usage?: UsageSnapshot): void {
  if (!ctx?.hasUI || !paceStatusEnabled) return;

  const pace =
    usage && !usage.error && usage.windows.length > 0 ? computePace(usage, new Date()) : undefined;
  if (!pace) {
    clearPaceStatus(ctx);
    return;
  }

  ctx.ui?.setStatus?.("sub-pace", formatPaceStatus(pace));
}

function computePace(usage: UsageSnapshot, now: Date): PaceResult | undefined {
  if (!usage.windows?.length) return undefined;

  const candidate = pickPaceWindow(usage);
  if (!candidate) return undefined;

  const { window, durationSeconds, resetAt } = candidate;
  const actual = clamp(window.usedPercent, 0, 100);
  const timeUntilReset = (resetAt.getTime() - now.getTime()) / 1000;

  if (!(timeUntilReset > 0) || !(durationSeconds > 0)) {
    return undefined;
  }

  const elapsedSeconds = clamp(durationSeconds - timeUntilReset, 0, durationSeconds);
  const expected = clamp((elapsedSeconds / durationSeconds) * 100, 0, 100);

  // Same guard codexbar applies: don't show pace immediately at window start.
  if (expected < 3) return undefined;

  const delta = actual - expected;
  const stage = stageForDelta(delta);

  let etaSeconds: number | undefined;
  let willLastToReset = false;

  if (elapsedSeconds > 0 && actual > 0) {
    const ratePerSecond = actual / elapsedSeconds;
    if (ratePerSecond > 0) {
      const remaining = Math.max(0, 100 - actual);
      const eta = remaining / ratePerSecond;
      if (eta >= timeUntilReset) {
        willLastToReset = true;
      } else {
        etaSeconds = eta;
      }
    }
  } else if (elapsedSeconds > 0 && actual === 0) {
    willLastToReset = true;
  }

  return {
    windowLabel: window.label,
    stage,
    deltaPercent: delta,
    expectedUsedPercent: expected,
    actualUsedPercent: actual,
    etaSeconds,
    willLastToReset,
  };
}

function pickPaceWindow(
  usage: UsageSnapshot
): { window: RateWindow; durationSeconds: number; resetAt: Date } | undefined {
  let best:
    | { window: RateWindow; durationSeconds: number; resetAt: Date; score: number }
    | undefined;

  for (const window of usage.windows) {
    if (!window.resetAt) continue;
    const resetAt = new Date(window.resetAt);
    if (Number.isNaN(resetAt.getTime())) continue;
    const durationSeconds = inferWindowDurationSeconds(window.label, usage.provider);
    if (!durationSeconds) continue;

    const candidate = {
      window,
      durationSeconds,
      resetAt,
      score: paceWindowScore(window.label, durationSeconds),
    };

    if (
      !best ||
      candidate.score > best.score ||
      (candidate.score === best.score && candidate.durationSeconds > best.durationSeconds)
    ) {
      best = candidate;
    }
  }

  return best
    ? { window: best.window, durationSeconds: best.durationSeconds, resetAt: best.resetAt }
    : undefined;
}

function inferWindowDurationSeconds(label: string, provider?: string): number | undefined {
  const text = (label || "").trim().toLowerCase();
  if (!text) return undefined;

  const hourMatch = text.match(/(\d+)\s*h/);
  if (hourMatch) {
    const hours = Number.parseInt(hourMatch[1], 10);
    if (Number.isFinite(hours) && hours > 0) return hours * 3600;
  }

  if (text.includes("week") || text.includes("7d") || text.includes("weekly")) return 7 * 24 * 3600;
  if (text.includes("day") || text.includes("24h") || text.includes("daily")) return 24 * 3600;
  if (text.includes("month") || text.includes("monthly")) return 30 * 24 * 3600;

  // Provider-specific fallbacks
  if (provider === "codex" && text.includes("primary")) return 5 * 3600;

  return undefined;
}

function paceWindowScore(label: string, durationSeconds: number): number {
  const text = (label || "").trim().toLowerCase();
  if (text.includes("week") || text.includes("7d") || text.includes("weekly")) return 500;
  if (text.includes("month") || text.includes("monthly")) return 400;
  if (text.includes("day") || text.includes("24h") || text.includes("daily")) return 300;
  if (text.includes("5h") || text.includes("primary") || text.includes("session")) return 200;
  return 100 + Math.round(durationSeconds / 3600);
}

function stageForDelta(delta: number): PaceStage {
  const absDelta = Math.abs(delta);
  if (absDelta <= 2) return "onTrack";
  if (absDelta <= 6) return delta >= 0 ? "slightlyAhead" : "slightlyBehind";
  if (absDelta <= 12) return delta >= 0 ? "ahead" : "behind";
  return delta >= 0 ? "farAhead" : "farBehind";
}

function formatPaceStatus(pace: PaceResult): string {
  const trend = formatPaceTrend(pace);

  const eta = pace.willLastToReset
    ? "should last"
    : pace.etaSeconds !== undefined
      ? `est. empty ${formatDuration(pace.etaSeconds)}`
      : "";

  return eta ? `Pace ${trend} · ${eta}` : `Pace ${trend}`;
}

function formatPaceTrend(pace: PaceResult): string {
  const delta = Math.round(Math.abs(pace.deltaPercent));
  if (pace.stage === "onTrack") return "on target";
  return pace.deltaPercent >= 0 ? `over budget ${delta}%` : `under budget ${delta}%`;
}

function formatPaceInline(pace: PaceResult): string {
  return `Pace (${pace.windowLabel}): ${formatPaceStatus(pace).replace(/^Pace\s*/i, "")}`;
}

function formatPaceDetail(usage: UsageSnapshot, pace: PaceResult): string {
  const provider = usage.displayName || usage.provider;
  const eta = pace.willLastToReset
    ? "Should last until reset"
    : pace.etaSeconds !== undefined
      ? `Estimated empty in ${formatDuration(pace.etaSeconds)}`
      : "ETA unavailable";

  return [
    `${provider} · ${pace.windowLabel}`,
    `Pace: ${formatPaceTrend(pace)}`,
    `Expected by now: ${Math.round(pace.expectedUsedPercent)}% used`,
    `Actual now: ${Math.round(pace.actualUsedPercent)}% used`,
    eta,
    `Guide: under budget = good; over budget = using faster than expected.`,
  ].join("\n");
}

function formatDuration(seconds: number): string {
  const s = Math.max(0, Math.round(seconds));
  if (s < 60) return "now";
  const mins = Math.floor(s / 60);
  if (mins < 60) return `${mins}m`;
  const hours = Math.floor(mins / 60);
  const remMins = mins % 60;
  if (hours < 48) return remMins > 0 ? `${hours}h${remMins}m` : `${hours}h`;
  const days = Math.floor(hours / 24);
  const remHours = hours % 24;
  return remHours > 0 ? `${days}d${remHours}h` : `${days}d`;
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}
