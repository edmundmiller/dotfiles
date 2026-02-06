/**
 * Superseded Writes Rule
 *
 * Removes older file write/edit operations when newer versions exist.
 * If the same file is written multiple times, only the latest write is kept.
 */

import type { PruneRule } from "../types";
import { extractFilePath, hashMessage } from "../metadata";

export const supersededWritesRule: PruneRule = {
  name: "superseded-writes",
  description: "Remove older file writes when newer versions exist",

  /**
   * Prepare phase: Extract file paths from write/edit operations
   */
  prepare(msg, ctx) {
    // Extract file path from write/edit tool results
    const filePath = extractFilePath(msg.message);

    if (filePath) {
      msg.metadata.filePath = filePath;
      // Store a version identifier (hash of the result)
      msg.metadata.fileVersion = hashMessage(msg.message);

      if (ctx.config.debug) {
        console.log(
          `[pi-dcp] SupersededWrites: found file operation at index ${ctx.index}: ${filePath}`
        );
      }
    }
  },

  /**
   * Process phase: Mark superseded writes for pruning
   */
  process(msg, ctx) {
    // Skip if already marked for pruning
    if (msg.metadata.shouldPrune) return;

    // Skip if not a file operation
    if (!msg.metadata.filePath) return;

    // Never prune user messages
    if (msg.message.role === "user") return;

    // Check if there's a later write to the same file
    const laterWrite = ctx.messages
      .slice(ctx.index + 1)
      .find((m) => m.metadata.filePath === msg.metadata.filePath);

    if (laterWrite) {
      msg.metadata.shouldPrune = true;
      msg.metadata.pruneReason = `superseded by later write to ${msg.metadata.filePath}`;

      if (ctx.config.debug) {
        console.log(
          `[pi-dcp] SupersededWrites: marking superseded write at index ${ctx.index}: ${msg.metadata.filePath}`
        );
      }
    }
  },
};
