/**
 * DCP Stats Command
 *
 * Show pruning statistics for the current session.
 */

import { CommandDefinition } from "../types";

export interface StatsTracker {
  totalPruned: number;
  totalProcessed: number;
}

export function createStatsCommand(
  statsTracker: StatsTracker,
  ruleCount: number
): CommandDefinition {
  return {
    description: "Show DCP pruning statistics for current session",
    handler: async (args, ctx) => {
      const { totalPruned, totalProcessed } = statsTracker;

      const message =
        `DCP Statistics:\n` +
        `  Total messages processed: ${totalProcessed}\n` +
        `  Total messages pruned: ${totalPruned}\n` +
        `  Pruning rate: ${totalProcessed > 0 ? ((totalPruned / totalProcessed) * 100).toFixed(1) : 0}%\n` +
        `  Active rules: ${ruleCount}`;

      ctx.ui.notify(message, "info");
    },
  };
}
