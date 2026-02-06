/**
 * Recency Rule
 *
 * Always preserves recent messages from pruning.
 * The last N messages (configurable via keepRecentCount) are protected
 * regardless of what other rules decide.
 *
 * This rule should typically run LAST in the process phase to override
 * other pruning decisions for recent messages.
 */

import type { PruneRule } from "../types";

export const recencyRule: PruneRule = {
  name: "recency",
  description: "Always preserve recent messages from pruning",

  /**
   * No prepare phase needed - recency is determined during processing
   */

  /**
   * Process phase: Protect recent messages from pruning
   */
  process(msg, ctx) {
    // Calculate distance from the end of the message list
    const distanceFromEnd = ctx.messages.length - ctx.index - 1;

    // If within the keepRecentCount threshold, protect it
    if (distanceFromEnd < ctx.config.keepRecentCount) {
      // Unmark for pruning if it was marked
      const wasPruned = msg.metadata.shouldPrune;
      msg.metadata.shouldPrune = false;
      msg.metadata.pruneReason = undefined;
      msg.metadata.protectedByRecency = true;

      if (ctx.config.debug && wasPruned) {
        console.log(
          `[pi-dcp] Recency: protecting message at index ${ctx.index} ` +
            `(distance from end: ${distanceFromEnd}, threshold: ${ctx.config.keepRecentCount})`
        );
      }
    }
  },
};
