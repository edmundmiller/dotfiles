import type { ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { truncateToWidth } from "@mariozechner/pi-tui";
import type { DumbZoneCheckResult } from "./checks";
import { CONTEXT_THRESHOLDS } from "./constants";
import { getEffectiveThreshold } from "./checks";

const STATUS_KEY = "dumb-zone";
const STATUS_BAR_LEN = 20;

/**
 * Severity level derived from check result.
 */
type Severity = "warning" | "danger" | "critical";

function getSeverity(result: DumbZoneCheckResult): Severity {
  const dangerThreshold = getEffectiveThreshold(CONTEXT_THRESHOLDS.DANGER, result.compacted);
  const criticalThreshold = getEffectiveThreshold(CONTEXT_THRESHOLDS.CRITICAL, result.compacted);

  if (result.utilization >= criticalThreshold) return "critical";
  if (result.utilization >= dangerThreshold) return "danger";
  return "warning";
}

function severityIcon(severity: Severity): string {
  switch (severity) {
    case "critical":
      return "!!!";
    case "danger":
      return "!!";
    case "warning":
      return "!";
  }
}

function severityLabel(severity: Severity): string {
  switch (severity) {
    case "critical":
      return "CRITICAL";
    case "danger":
      return "DANGER";
    case "warning":
      return "WARNING";
  }
}

function clampPercent(percent: number): number {
  if (Number.isNaN(percent)) return 0;
  if (percent < 0) return 0;
  if (percent > 100) return 100;
  return percent;
}

function getZoneLabel(utilization: number, warningThreshold: number, dangerThreshold: number): string {
  if (utilization < warningThreshold) return "smart";
  if (utilization < dangerThreshold) return "warm";
  return "dumb";
}

function getZoneCeiling(utilization: number, warningThreshold: number, dangerThreshold: number): number {
  if (utilization < warningThreshold) return warningThreshold;
  if (utilization < dangerThreshold) return dangerThreshold;
  return 100;
}

function buildProgressBar(utilization: number, warningThreshold: number, dangerThreshold: number): string {
  const filled = Math.max(0, Math.min(STATUS_BAR_LEN, Math.round((utilization / 100) * STATUS_BAR_LEN)));
  const warningPos = Math.round((warningThreshold / 100) * STATUS_BAR_LEN);
  const dangerPos = Math.round((dangerThreshold / 100) * STATUS_BAR_LEN);

  let bar = "";
  for (let i = 0; i < STATUS_BAR_LEN; i++) {
    if ((i === warningPos && warningPos > 0 && warningPos < STATUS_BAR_LEN) ||
      (i === dangerPos && dangerPos > 0 && dangerPos < STATUS_BAR_LEN)) {
      bar += "|";
      continue;
    }
    bar += i < filled ? "█" : "░";
  }

  return bar;
}

export function renderContextZoneStatus(result: DumbZoneCheckResult): string {
  const utilization = clampPercent(result.utilization);
  const warningThreshold = getEffectiveThreshold(CONTEXT_THRESHOLDS.WARNING, result.compacted);
  const dangerThreshold = getEffectiveThreshold(CONTEXT_THRESHOLDS.DANGER, result.compacted);
  const zoneLabel = getZoneLabel(utilization, warningThreshold, dangerThreshold);
  const zoneCeiling = getZoneCeiling(utilization, warningThreshold, dangerThreshold);
  const left = Math.max(0, Math.round(zoneCeiling - utilization));

  const bar = buildProgressBar(utilization, warningThreshold, dangerThreshold);
  const patternSuffix = result.violationType === "pattern" ? " pattern" : "";
  const compactedSuffix = result.compacted ? " compacted" : "";

  return `CZ ${bar} ${zoneLabel} ${left}% left${patternSuffix}${compactedSuffix}`;
}

/**
 * Update the persistent footer status bar with dumb zone info.
 * Shows a compact warning at the bottom of the screen.
 */
export function updateStatusBar(ctx: ExtensionContext, result: DumbZoneCheckResult): void {
  if (!ctx.hasUI) return;

  ctx.ui.setStatus(STATUS_KEY, renderContextZoneStatus(result));
}

/**
 * Update the persistent top-of-screen banner widget.
 * Shows a prominent warning that persists above the editor.
 */
export function updateTopBanner(ctx: ExtensionContext, result: DumbZoneCheckResult): void {
  if (!ctx.hasUI) return;

  if (!result.inZone) {
    ctx.ui.setWidget("dumb-zone", undefined);
    return;
  }

  const severity = getSeverity(result);

  ctx.ui.setWidget(
    "dumb-zone",
    (_tui: unknown, theme: Theme) => {
      return new DumbZoneBanner(theme, result, severity);
    },
    { placement: "aboveEditor" }
  );
}

/**
 * Clear all persistent dumb zone notifications.
 */
export function clearNotifications(ctx: ExtensionContext): void {
  if (!ctx.hasUI) return;
  ctx.ui.setStatus(STATUS_KEY, undefined);
  ctx.ui.setWidget(STATUS_KEY, undefined);
}

class DumbZoneBanner {
  constructor(
    private readonly theme: Theme,
    private readonly result: DumbZoneCheckResult,
    private readonly severity: Severity
  ) {}

  render(width: number): string[] {
    const icon = severityIcon(this.severity);
    const label = severityLabel(this.severity);
    const pct = this.result.utilization.toFixed(0);

    const color = this.severity === "warning" ? "warning" : "error";

    const msg = `${icon} DUMB ZONE ${label}: Context at ${pct}%`;
    const hint =
      this.severity === "critical"
        ? " — start a new session!"
        : this.severity === "danger"
          ? " — consider compacting or forking"
          : " — context filling up";

    const full = truncateToWidth(`${msg}${hint}`, width, "");
    const styled = this.theme.fg(color, this.theme.bold(full));

    const separator = this.theme.fg("border", "─".repeat(width));

    return [styled, separator];
  }

  invalidate(): void {}
}
