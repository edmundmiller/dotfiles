/**
 * Pruning workflow engine
 *
 * Implements the prepare > process > filter workflow for message pruning.
 */

import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { DcpConfigWithPruneRuleObjects, MessageWithMetadata } from "./types";
import {
  createMessageWithMetadata,
  extractToolUseIds,
  hasToolUse,
  hasToolResult,
} from "./metadata";
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

  // Phase 3.5: REPAIR - Fix orphaned tool pairs from rule-ordering interactions
  repairOrphanedToolPairs(withMetadata, config);

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
 * Post-process safety net: fix orphaned tool pairs that slip through
 * rule-ordering interactions (e.g. dedup + recency boundary split).
 *
 * Algorithm:
 * 1. Collect tool_use IDs from all kept assistant messages
 * 2. For each kept tool_result, check if its ID is in the set
 * 3. If orphaned: un-prune the matching assistant, add its IDs
 * 4. Second pass: un-prune tool_results paired with resurrected assistants
 */
function repairOrphanedToolPairs(
  messages: MessageWithMetadata[],
  config: DcpConfigWithPruneRuleObjects
): void {
  const logger = getLogger();

  // Collect tool_use IDs from kept assistant messages
  const keptToolUseIds = new Set<string>();
  for (const msg of messages) {
    if (msg.metadata.shouldPrune) continue;
    if (!hasToolUse(msg.message)) continue;
    for (const id of extractToolUseIds(msg.message)) {
      keptToolUseIds.add(id);
    }
  }

  // Find orphaned tool_results and resurrect their assistants
  const resurrectedAssistants: MessageWithMetadata[] = [];
  for (const msg of messages) {
    if (msg.metadata.shouldPrune) continue;
    if (!hasToolResult(msg.message)) continue;
    const resultIds = extractToolUseIds(msg.message);
    for (const id of resultIds) {
      if (keptToolUseIds.has(id)) continue;
      // Orphaned — find and resurrect the matching assistant
      for (const candidate of messages) {
        if (!candidate.metadata.shouldPrune) continue;
        if (!hasToolUse(candidate.message)) continue;
        const candidateIds = extractToolUseIds(candidate.message);
        if (candidateIds.includes(id)) {
          candidate.metadata.shouldPrune = false;
          candidate.metadata.pruneReason = undefined;
          candidate.metadata.repairedOrphan = true;
          resurrectedAssistants.push(candidate);
          for (const cid of candidateIds) keptToolUseIds.add(cid);
          if (config.debug) {
            logger.debug(`Repair: resurrected assistant with tool_use ${id}`);
          }
          break;
        }
      }
    }
  }

  // Second pass: un-prune tool_results paired with resurrected assistants
  for (const ast of resurrectedAssistants) {
    const astIds = extractToolUseIds(ast.message);
    for (const msg of messages) {
      if (!msg.metadata.shouldPrune) continue;
      if (!hasToolResult(msg.message)) continue;
      const resultIds = extractToolUseIds(msg.message);
      if (resultIds.some((id) => astIds.includes(id))) {
        msg.metadata.shouldPrune = false;
        msg.metadata.pruneReason = undefined;
        msg.metadata.repairedOrphan = true;
        if (config.debug) {
          logger.debug(`Repair: un-pruned tool_result paired with resurrected assistant`);
        }
      }
    }
  }
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
