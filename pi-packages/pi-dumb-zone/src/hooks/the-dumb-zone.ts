import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { checkDumbZone, getEffectiveThreshold } from "../checks";
import { CONTEXT_THRESHOLDS } from "../constants";
import { updateStatusBar, updateTopBanner } from "../notifications";
import { triggerDumbZoneOverlay } from "../overlay";

/**
 * Setup the dumb zone detection hook.
 * Runs checks after each agent turn with escalating notifications:
 * - WARNING: footer status bar + top banner (persistent, non-intrusive)
 * - DANGER+: popup overlay (once per cooldown, intrusive) + persistent indicators
 */
export function setupDumbZoneHook(pi: ExtensionAPI): void {
  pi.on("agent_end", async (event, ctx) => {
    const result = checkDumbZone(ctx, event.messages);

    // Always update persistent indicators (show at WARNING, clear when OK)
    updateStatusBar(ctx, result);
    updateTopBanner(ctx, result);

    if (!result.inZone) return;

    // Popup overlay only at DANGER threshold or pattern violations
    const dangerThreshold = getEffectiveThreshold(CONTEXT_THRESHOLDS.DANGER, result.compacted);
    if (result.utilization >= dangerThreshold || result.violationType === "pattern") {
      triggerDumbZoneOverlay(ctx, result.details);
    }
  });
}
