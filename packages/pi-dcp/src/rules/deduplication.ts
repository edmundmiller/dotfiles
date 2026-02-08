/**
 * Deduplication Rule
 *
 * Removes duplicate tool outputs based on content hash.
 * Messages with identical content are considered duplicates,
 * and only the first occurrence is kept.
 */

import type { PruneRule } from "../types";
import { hashMessage } from "../metadata";
import { getLogger } from "../logger";

export const deduplicationRule: PruneRule = {
  name: "deduplication",
  description: "Remove duplicate tool outputs based on content hash",

  /**
   * Prepare phase: Hash each message for comparison
   */
  prepare(msg, ctx) {
    // Hash the message content
    msg.metadata.hash = hashMessage(msg.message);
  },

  /**
   * Process phase: Mark duplicates for pruning
   */
  process(msg, ctx) {
    // Skip if already marked for pruning by another rule
    if (msg.metadata.shouldPrune) return;

    // Never prune user messages
    if (msg.message.role === "user") return;

    // Never prune assistant messages with tool calls — each invocation is unique
    if (msg.metadata.hasToolUse) return;

    // Check if we've seen this exact content before
    const currentHash = msg.metadata.hash;
    if (!currentHash) return;

    // Look for earlier message with same hash
    const seenBefore = ctx.messages
      .slice(0, ctx.index)
      .some((m) => m.metadata.hash === currentHash);

    if (seenBefore) {
      msg.metadata.shouldPrune = true;
      msg.metadata.pruneReason = "duplicate content";

      if (ctx.config.debug) {
        getLogger().debug(
          `Dedup: marking duplicate message at index ${ctx.index} (hash: ${currentHash})`
        );
      }
    }
  },
};
