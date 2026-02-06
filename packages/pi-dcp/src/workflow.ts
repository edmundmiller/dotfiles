/**
 * Pruning workflow engine
 *
 * Implements the prepare > process > filter workflow for message pruning.
 */

import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { DcpConfigWithPruneRuleObjects, MessageWithMetadata } from "./types";
import { createMessageWithMetadata } from "./metadata";
import { resolveRule } from "./registry";
import { getLogger } from "./logger";

/**
 * Main workflow: prepare > process > filter
 *
 * @param messages - Original messages from pi
 * @param config - DCP configuration
 * @returns Filtered messages with pruned items removed
 */
export function applyPruningWorkflow(
  messages: AgentMessage[],
  config: DcpConfigWithPruneRuleObjects
): AgentMessage[] {
  if (!config.enabled) {
    return messages; // Pass through if disabled
  }

  if (messages.length === 0) {
    return messages; // Nothing to prune
  }

  // Phase 1: Wrap messages with metadata containers
  const withMetadata = messages.map(createMessageWithMetadata);

  // Phase 2: PREPARE - Run prepare phase for all rules
  const logger = getLogger();

  for (const ruleRef of config.rules) {
    const rule = resolveRule(ruleRef);

    if (rule.prepare) {
      withMetadata.forEach((msg, index) => {
        try {
          rule.prepare!(msg, {
            messages: withMetadata,
            index,
            config,
          });
        } catch (error) {
          logger.error(`Error in prepare phase for rule "${rule.name}"`, {
            error: error instanceof Error ? error.message : String(error),
            rule: rule.name,
            index,
          });
        }
      });
    }
  }

  if (config.debug) {
    logger.debug(`Prepare phase complete. Processed ${withMetadata.length} messages.`);
  }

  // Phase 3: PROCESS - Run process phase for all rules
  for (const ruleRef of config.rules) {
    const rule = resolveRule(ruleRef);

    if (rule.process) {
      withMetadata.forEach((msg, index) => {
        try {
          rule.process!(msg, {
            messages: withMetadata,
            index,
            config,
          });
        } catch (error) {
          logger.error(`Error in process phase for rule "${rule.name}"`, {
            error: error instanceof Error ? error.message : String(error),
            rule: rule.name,
            index,
          });
        }
      });
    }
  }

  if (config.debug) {
    logger.debug(`Process phase complete.`);
  }

  // Phase 4: FILTER - Remove messages marked for pruning
  const filtered = withMetadata.filter((m) => !m.metadata.shouldPrune).map((m) => m.message);

  // Log results
  const prunedCount = messages.length - filtered.length;
  if (config.debug || prunedCount > 0) {
    logPruningResults(withMetadata, filtered.length, config);
  }

  return filtered;
}

/**
 * Log pruning results for debugging
 */
function logPruningResults(
  withMetadata: MessageWithMetadata[],
  finalCount: number,
  config: DcpConfigWithPruneRuleObjects
): void {
  const logger = getLogger();
  const prunedMessages = withMetadata.filter((m) => m.metadata.shouldPrune);
  const prunedCount = prunedMessages.length;
  const originalCount = withMetadata.length;

  logger.info(
    `Filter phase complete: ${prunedCount} pruned, ${finalCount} kept (${originalCount} total)`
  );

  if (config.debug && prunedCount > 0) {
    logger.debug(`Pruned messages:`, {
      pruned: prunedMessages.map((msg) => ({
        index: withMetadata.indexOf(msg),
        role: msg.message.role,
        reason: msg.metadata.pruneReason || "unknown",
      })),
    });
  }
}

/**
 * Get pruning statistics (for future /dcp-stats command)
 */
export interface PruningStats {
  totalMessages: number;
  prunedCount: number;
  keptCount: number;
  pruneReasons: Record<string, number>;
}

export function getPruningStats(withMetadata: MessageWithMetadata[]): PruningStats {
  const pruned = withMetadata.filter((m) => m.metadata.shouldPrune);
  const pruneReasons: Record<string, number> = {};

  pruned.forEach((msg) => {
    const reason = msg.metadata.pruneReason || "unknown";
    pruneReasons[reason] = (pruneReasons[reason] || 0) + 1;
  });

  return {
    totalMessages: withMetadata.length,
    prunedCount: pruned.length,
    keptCount: withMetadata.length - pruned.length,
    pruneReasons,
  };
}
