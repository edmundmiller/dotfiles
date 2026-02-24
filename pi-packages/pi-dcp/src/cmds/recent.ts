/**
 * DCP Recent Command
 *
 * Adjust the recency threshold (number of recent messages to always keep).
 */

import type { CommandDefinition, DcpConfig } from "../types";

export function createRecentCommand(config: DcpConfig): CommandDefinition {
  return {
    description: "Set the number of recent messages to always keep (e.g., /dcp-recent 15)",
    handler: async (args, ctx) => {
      const count = parseInt(args || "10", 10);
      if (isNaN(count) || count < 0) {
        ctx.ui.notify("Invalid count. Usage: /dcp-recent <number>", "error");
        return;
      }
      config.keepRecentCount = count;
      ctx.ui.notify(`DCP: keeping last ${count} messages`, "info");
    },
  };
}
