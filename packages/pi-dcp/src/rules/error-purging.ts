/**
 * Error Purging Rule
 *
 * Removes resolved errors from context.
 * If an error is followed by a successful retry of the same operation,
 * the error can be pruned as it's no longer relevant.
 */

import type { PruneRule } from "../types";
import { isErrorMessage, isSameOperation } from "../metadata";
import { getLogger } from "../logger";

export const errorPurgingRule: PruneRule = {
  name: "error-purging",
  description: "Remove resolved errors from context",

  /**
   * Prepare phase: Identify errors and check if they were resolved
   */
  prepare(msg, ctx) {
    // Mark if message is an error
    const isError = isErrorMessage(msg.message);
    msg.metadata.isError = isError;

    if (isError) {
      // Look ahead for a successful retry of the same operation
      const laterSuccess = ctx.messages
        .slice(ctx.index + 1)
        .find((m) => isSameOperation(m.message, msg.message) && !isErrorMessage(m.message));

      msg.metadata.errorResolved = !!laterSuccess;

      if (ctx.config.debug && laterSuccess) {
        getLogger().debug(`ErrorPurging: found resolved error at index ${ctx.index}`);
      }
    }
  },

  /**
   * Process phase: Mark resolved errors for pruning
   */
  process(msg, ctx) {
    // Skip if already marked for pruning
    if (msg.metadata.shouldPrune) return;

    // Never prune user messages
    if (msg.message.role === "user") return;

    // Prune if it's an error that was resolved
    if (msg.metadata.isError && msg.metadata.errorResolved) {
      msg.metadata.shouldPrune = true;
      msg.metadata.pruneReason = "error resolved by later success";

      if (ctx.config.debug) {
        getLogger().debug(`ErrorPurging: marking resolved error at index ${ctx.index}`);
      }
    }
  },
};
