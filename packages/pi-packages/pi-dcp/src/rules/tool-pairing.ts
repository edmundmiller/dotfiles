/**
 * Tool Pairing Rule
 *
 * Ensures that tool_use and tool_result blocks are never separated.
 * Claude's API requires that every tool_result has a corresponding tool_use
 * in the previous assistant message.
 *
 * Algorithm:
 * 1. Prepare: Extract tool IDs and type flags from each message
 * 2. Process: Two passes:
 *    - First pass (forward): If tool_use is pruned, cascade prune to tool_result
 *    - Second pass (backward): If tool_result is kept, protect tool_use
 *
 * This rule MUST run AFTER all other pruning rules to protect tool pairs.
 */

import type { PruneRule, ProcessContext, MessageWithMetadata } from "../types";
import { extractToolUseIds, hasToolUse, hasToolResult } from "../metadata";
import { getLogger } from "../logger";

export const toolPairingRule: PruneRule = {
  name: "tool-pairing",
  description: "Preserve tool_use/tool_result pairing required by Claude API",

  /**
   * Prepare phase: Extract tool_use IDs from each message
   */
  prepare(msg, ctx) {
    msg.metadata.toolUseIds = extractToolUseIds(msg.message);
    msg.metadata.hasToolUse = hasToolUse(msg.message);
    msg.metadata.hasToolResult = hasToolResult(msg.message);
  },

  /**
   * Process phase: Prevent breaking tool_use/tool_result pairs
   */
  process(msg, ctx) {
    // PASS 1 (Forward): If tool_use is pruned, cascade prune to tool_result
    cascadePruneForward(msg, ctx);

    // PASS 2 (Backward): If tool_result is kept, protect tool_use
    protectToolUseBackward(msg, ctx);
  },
};

/**
 * Forward pass: If a tool_use is pruned, prune its corresponding tool_result
 * Also: If a tool_use is kept, protect its corresponding tool_result
 */
function cascadePruneForward(msg: MessageWithMetadata, ctx: ProcessContext): void {
  if (!msg.metadata.hasToolUse) return;
  if (!msg.metadata.toolUseIds || msg.metadata.toolUseIds.length === 0) return;

  const toolUseIds = msg.metadata.toolUseIds;
  const isPruned = msg.metadata.shouldPrune;

  // Find next messages with matching tool_result
  for (let i = ctx.index + 1; i < ctx.messages.length; i++) {
    const nextMsg = ctx.messages[i];

    // Only consider messages with tool_result
    if (!nextMsg.metadata.hasToolResult) continue;
    if (!nextMsg.metadata.toolUseIds) continue;

    // Check if this tool_result matches our tool_use
    const hasMatchingToolResult = toolUseIds.some((id: string) =>
      nextMsg.metadata.toolUseIds?.includes(id)
    );

    if (hasMatchingToolResult) {
      if (isPruned && !nextMsg.metadata.shouldPrune) {
        // tool_use is pruned, cascade to tool_result
        nextMsg.metadata.shouldPrune = true;
        nextMsg.metadata.pruneReason = "orphaned tool_result (tool_use was pruned)";

        if (ctx.config.debug) {
          getLogger().debug(
            `Tool-pairing: cascade pruning tool_result at index ${i} ` +
              `(tool_use at index ${ctx.index} was pruned)`
          );
        }
      } else if (!isPruned && nextMsg.metadata.shouldPrune) {
        // tool_use is kept, protect tool_result
        nextMsg.metadata.shouldPrune = false;
        nextMsg.metadata.pruneReason = undefined;
        nextMsg.metadata.protectedByToolPairing = true;

        if (ctx.config.debug) {
          getLogger().debug(
            `Tool-pairing: protecting tool_result at index ${i} ` +
              `(tool_use at index ${ctx.index} is kept)`
          );
        }
      }
    }
  }
}

/**
 * Backward pass: If a tool_result is kept, protect its tool_use
 */
function protectToolUseBackward(msg: MessageWithMetadata, ctx: ProcessContext): void {
  // Only process messages with tool_result that are NOT marked for pruning
  if (!msg.metadata.hasToolResult || msg.metadata.shouldPrune) return;
  if (!msg.metadata.toolUseIds || msg.metadata.toolUseIds.length === 0) return;

  const toolUseIds = msg.metadata.toolUseIds;

  // Find previous messages with matching tool_use
  for (let i = ctx.index - 1; i >= 0; i--) {
    const prevMsg = ctx.messages[i];

    // Only consider messages with tool_use
    if (!prevMsg.metadata.hasToolUse) continue;
    if (!prevMsg.metadata.toolUseIds) continue;

    // Check if this tool_use matches our kept tool_result
    const hasMatchingToolUse = toolUseIds.some((id: string) =>
      prevMsg.metadata.toolUseIds?.includes(id)
    );

    if (hasMatchingToolUse && prevMsg.metadata.shouldPrune) {
      // Protect the tool_use
      prevMsg.metadata.shouldPrune = false;
      prevMsg.metadata.pruneReason = undefined;
      prevMsg.metadata.protectedByToolPairing = true;

      if (ctx.config.debug) {
        getLogger().debug(
          `Tool-pairing: protecting tool_use at index ${i} ` +
            `(referenced by kept tool_result at index ${ctx.index})`
        );
      }

      // Also protect the tool_result for this tool_use
      // (in case it was also marked for pruning by deduplication)
      protectMatchingToolResults(prevMsg, i, ctx);
    }
  }
}

/**
 * Helper: When a tool_use is protected, also protect its tool_results
 */
function protectMatchingToolResults(
  toolUseMsg: MessageWithMetadata,
  toolUseIndex: number,
  ctx: ProcessContext
): void {
  if (!toolUseMsg.metadata.toolUseIds) return;

  const toolUseIds = toolUseMsg.metadata.toolUseIds;

  for (let i = toolUseIndex + 1; i < ctx.messages.length; i++) {
    const nextMsg = ctx.messages[i];

    if (!nextMsg.metadata.hasToolResult) continue;
    if (!nextMsg.metadata.toolUseIds) continue;

    const hasMatchingToolResult = toolUseIds.some((id: string) =>
      nextMsg.metadata.toolUseIds?.includes(id)
    );

    if (hasMatchingToolResult && nextMsg.metadata.shouldPrune) {
      nextMsg.metadata.shouldPrune = false;
      nextMsg.metadata.pruneReason = undefined;
      nextMsg.metadata.protectedByToolPairing = true;

      if (ctx.config.debug) {
        getLogger().debug(
          `Tool-pairing: protecting tool_result at index ${i} ` +
            `(paired with protected tool_use at index ${toolUseIndex})`
        );
      }
    }
  }
}
