/**
 * DCP Context Event Handler
 *
 * Handles the 'context' event which fires before each LLM call.
 * Applies pruning workflow to reduce token usage while preserving coherence.
 */

import type { ContextEvent, ExtensionContext } from "@mariozechner/pi-coding-agent";
import type { DcpConfigWithPruneRuleObjects } from "../types";
import type { StatsTracker } from "../cmds/stats.ts";
import { applyPruningWorkflow } from "../workflow";

export interface ContextEventHandlerOptions {
  config: DcpConfigWithPruneRuleObjects;
  statsTracker: StatsTracker;
}

/**
 * Creates a context event handler that applies pruning to messages.
 *
 * @param options - Configuration and stats tracker
 * @returns Event handler function
 */
export function createContextEventHandler(options: ContextEventHandlerOptions) {
  const { config, statsTracker } = options;

  return async (event: ContextEvent, ctx: ExtensionContext) => {
    try {
      const originalCount = event.messages.length;

      // Apply pruning workflow
      const prunedMessages = applyPruningWorkflow(event.messages, config);

      const prunedCount = originalCount - prunedMessages.length;
      statsTracker.totalPruned += prunedCount;
      statsTracker.totalProcessed += originalCount;

      if (prunedCount > 0) {
        // Show toast notification when pruning occurs
        // ctx. //(`DCP: Pruned ${prunedCount}/${originalCount} messages`, "info");
      }

      if (config.debug) {
        ctx.ui.notify(`[pi-dcp] Pruned ${prunedCount} / ${originalCount} messages`);
      }

      return { messages: prunedMessages };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`[pi-dcp] Error in pruning workflow: ${errorMessage}`, "error");
      // Fail-safe: return original messages on error
      return { messages: event.messages };
    }
  };
}
