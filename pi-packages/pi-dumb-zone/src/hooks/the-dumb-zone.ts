import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { checkDumbZone } from "../checks";
import { triggerDumbZoneOverlay } from "../overlay";

/**
 * Setup the dumb zone detection hook.
 * Runs checks after each agent turn and displays overlay if violations detected.
 */
export function setupDumbZoneHook(pi: ExtensionAPI): void {
  pi.on("agent_end", async (event, ctx) => {
    const result = checkDumbZone(ctx, event.messages);

    if (result.inZone) {
      triggerDumbZoneOverlay(ctx, result.details);
    }
  });
}
