import type { ExtensionContext, Theme } from "@mariozechner/pi-coding-agent";
import { truncateToWidth } from "@mariozechner/pi-tui";
import type { DumbZoneCheckResult } from "./checks";
import { CONTEXT_THRESHOLDS } from "./constants";
import { getEffectiveThreshold } from "./checks";

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

/**
 * Update the persistent footer status bar with dumb zone info.
 * Shows a compact warning at the bottom of the screen.
 */
export function updateStatusBar(ctx: ExtensionContext, result: DumbZoneCheckResult): void {
  if (!ctx.hasUI) return;

  if (!result.inZone) {
    ctx.ui.setStatus("dumb-zone", undefined);
    return;
  }

  const severity = getSeverity(result);
  const icon = severityIcon(severity);
  const pct = result.utilization.toFixed(0);
  const label = severityLabel(severity);

  const suffix = result.violationType === "pattern" ? " [pattern]" : "";
  ctx.ui.setStatus("dumb-zone", `${icon} DUMB ZONE ${label}: ${pct}%${suffix}`);
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
  ctx.ui.setStatus("dumb-zone", undefined);
  ctx.ui.setWidget("dumb-zone", undefined);
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
