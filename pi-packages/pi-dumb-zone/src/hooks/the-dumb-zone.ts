import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { checkDumbZone, getEffectiveThreshold } from "../checks";
import { CONTEXT_THRESHOLDS } from "../constants";
import { updateTopBanner } from "../notifications";
import { triggerDumbZoneOverlay } from "../overlay";
import { publishSignal, clearSignal, type DumbZoneSignal } from "../signal";

/**
 * Setup the dumb zone detection hook.
 * Runs checks after each agent turn with escalating notifications:
 * - WARNING: footer status bar + top banner (persistent, non-intrusive)
 * - DANGER+: popup overlay (once per cooldown, intrusive) + persistent indicators
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
    updateTopBanner(ctx, result);

    if (!result.inZone) return;

    // Overlay at DANGER+
    const dangerThreshold = getEffectiveThreshold(CONTEXT_THRESHOLDS.DANGER, result.compacted);
    if (result.utilization >= dangerThreshold || result.violationType === "pattern") {
      triggerDumbZoneOverlay(ctx, result.details);
    }
  });
}
