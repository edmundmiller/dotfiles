/**
 * DCP Debug Command
 *
 * Toggle debug logging to see what gets pruned.
 */

import type { CommandDefinition, DcpConfig } from "../types";

export function createDebugCommand(config: DcpConfig): CommandDefinition {
  return {
    description: "Toggle DCP debug logging",
    handler: async (args, ctx) => {
      config.debug = !config.debug;
      ctx.ui.notify(`DCP debug: ${config.debug ? "ON" : "OFF"}`, "info");
    },
  };
}
