import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { setupDumbZoneCommands } from "./src/commands";
import { setupDumbZoneHooks } from "./src/hooks";

/**
 * The Dumb Zone Extension
 *
 * Detects context window degradation via quantitative (token usage)
 * and qualitative (phrase pattern) checks. Shows overlay warnings
 * when the agent enters the "dumb zone".
 *
 * Forked from @aliou/pi-the-dumb-zone with custom thresholds.
 */
export default function (pi: ExtensionAPI) {
  setupDumbZoneHooks(pi);
  setupDumbZoneCommands(pi);
}
