import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Text, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import { setupDumbZoneCommands } from "./src/commands";
import { setupDumbZoneHooks } from "./src/hooks";

let tuiOverflowGuardInstalled = false;

function installTuiOverflowGuard(): void {
  if (tuiOverflowGuardInstalled) return;
  tuiOverflowGuardInstalled = true;

  // Safety net for long status lines: keep Text output within viewport width.
  const originalRender = Text.prototype.render;
  Object.defineProperty(Text.prototype, "render", {
    configurable: true,
    writable: true,
    value(width: number): string[] {
      const lines = originalRender.call(this, width);
      return lines.map((line) =>
        visibleWidth(line) > width ? truncateToWidth(line, width, "", false) : line
      );
    },
  });
}

installTuiOverflowGuard();

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
