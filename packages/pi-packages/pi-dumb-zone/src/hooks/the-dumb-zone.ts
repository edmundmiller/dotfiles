import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { checkDumbZone, getEffectiveThreshold } from "../checks";
import {
  AUTO_COMPACT_THRESHOLD,
  CONTEXT_THRESHOLDS,
  SHOW_DANGER_OVERLAY,
  SHOW_TOP_BANNER,
} from "../constants";
import { updateStatusBar, updateTopBanner } from "../notifications";
import { triggerDumbZoneOverlay } from "../overlay";
import { publishSignal, clearSignal, type DumbZoneSignal } from "../signal";

/**
 * Setup the dumb zone detection hook.
 * Runs checks after each agent turn with escalating responses:
 * - WARNING: status bar indicator (always on)
 * - WARNING: optional top banner (disabled by default)
 * - DANGER: optional popup overlay (disabled by default)
 * - AUTO_COMPACT_THRESHOLD: auto-compact (disabled by default)
 *
 * Also publishes a globalThis signal so other extensions (e.g. pi-dcp)
 * can optionally react to dumb zone state.
 */
export function setupDumbZoneHook(pi: ExtensionAPI): void {
  pi.on("agent_end", async (event, ctx) => {
    const result = checkDumbZone(ctx, event.messages);

    // Publish signal for cross-extension coordination
    if (result.inZone) {
      const dangerThreshold = getEffectiveThreshold(CONTEXT_THRESHOLDS.DANGER, result.compacted);
      const criticalThreshold = getEffectiveThreshold(
        CONTEXT_THRESHOLDS.CRITICAL,
        result.compacted
      );

      const severity: DumbZoneSignal["severity"] =
        result.utilization >= criticalThreshold
          ? "critical"
          : result.utilization >= dangerThreshold
            ? "danger"
            : "warning";

      publishSignal({
        inZone: true,
        utilization: result.utilization,
        severity,
        compacted: result.compacted,
        timestamp: Date.now(),
      });
    } else {
      clearSignal();
    }

    // Visual notifications
    updateStatusBar(ctx, result);
    if (SHOW_TOP_BANNER) {
      updateTopBanner(ctx, result);
    }

    if (!result.inZone) return;

    // Auto-compact: fire once when hitting threshold (skip if already compacted)
    if (
      AUTO_COMPACT_THRESHOLD > 0 &&
      !result.compacted &&
      result.utilization >= AUTO_COMPACT_THRESHOLD
    ) {
      if (ctx.hasUI) {
        ctx.ui.notify(
          `Dumb zone auto-compact: context at ${result.utilization.toFixed(0)}%`,
          "warning"
        );
      }
      ctx.compact({
        onComplete: () => {
          if (ctx.hasUI) {
            ctx.ui.notify("Auto-compact complete", "info");
          }
        },
        onError: (error) => {
          if (ctx.hasUI) {
            ctx.ui.notify(`Auto-compact failed: ${error.message}`, "error");
          }
        },
      });
      return; // skip overlay - compaction handles it
    }

    // Overlay at DANGER+ (only if not auto-compacting)
    const dangerThreshold = getEffectiveThreshold(CONTEXT_THRESHOLDS.DANGER, result.compacted);
    if (
      SHOW_DANGER_OVERLAY &&
      (result.utilization >= dangerThreshold || result.violationType === "pattern")
    ) {
      triggerDumbZoneOverlay(ctx, result.details);
    }
  });
}
