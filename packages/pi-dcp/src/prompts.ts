/**
 * Prompts for LLM-driven context management
 *
 * System prompt injection, prunable-tools list, and nudge templates.
 */

import type { ToolCacheEntry } from "./tool-cache";

/**
 * System prompt appended via before_agent_start event.
 * Teaches the LLM about DCP tools and when to use them.
 */
export const SYSTEM_PROMPT = `
## Context Management (DCP)

You have access to context management tools that help keep conversations efficient:

- **dcp_prune**: Remove tool outputs that are no longer needed (e.g., old file reads superseded by edits, resolved errors, redundant listings)
- **dcp_distill**: Replace verbose tool outputs with concise summaries while preserving key information
- **dcp_compress**: Compress a range of conversation into a summary, removing the original messages

### When to Use
- After completing a subtask, prune tool outputs from that phase
- When context feels bloated with old reads/listings
- Before starting a new phase of work
- When you see the <prunable-tools> list and notice large, stale outputs

### Guidelines
- Never prune tool outputs you're still actively using
- Prefer distill over prune when the information might be needed later
- Use compress for long stretches of back-and-forth that can be summarized
- Write/edit outputs are safe to prune since the file system is the source of truth
`.trim();

/** Max entries to show in the prunable-tools list (largest by token count) */
const MAX_PRUNABLE_ENTRIES = 10;

/**
 * Build the <prunable-tools> block that gets injected into context.
 * Uses numeric IDs so the LLM can reference them in dcp_prune/dcp_distill calls.
 * Shows only the top N largest entries to avoid flooding context.
 */
export function buildPrunableToolsList(
  entries: { numericId: number; entry: ToolCacheEntry }[]
): string | null {
  if (entries.length === 0) return null;

  // Sort by token count descending, show only the largest
  const sorted = [...entries].sort((a, b) => b.entry.tokenCount - a.entry.tokenCount);
  const shown = sorted.slice(0, MAX_PRUNABLE_ENTRIES);
  const hidden = entries.length - shown.length;

  const lines = shown.map(({ numericId, entry }) => {
    const tokens = entry.tokenCount > 0 ? ` (~${entry.tokenCount} tokens)` : "";
    const error = entry.isError ? " [ERROR]" : "";
    return `  ${numericId}: ${entry.toolName}(${entry.paramKey})${tokens}${error}`;
  });

  const parts = [
    "<prunable-tools>",
    "The following tool outputs can be pruned or distilled to save context:",
    ...lines,
  ];
  if (hidden > 0) {
    parts.push(`  ... and ${hidden} smaller entries`);
  }
  parts.push("Use dcp_prune or dcp_distill with these numeric IDs to manage context.");
  parts.push("</prunable-tools>");

  return parts.join("\n");
}

/**
 * Periodic nudge — reminds the LLM to consider pruning
 */
export const NUDGE_PROMPT = `
<dcp-nudge>
Consider reviewing the <prunable-tools> list above. If any tool outputs are stale or superseded, use dcp_prune or dcp_distill to free up context space.
</dcp-nudge>
`.trim();

/**
 * Compress nudge — when context is getting large
 */
export const COMPRESS_NUDGE_PROMPT = `
<dcp-nudge priority="high">
Context is getting large. Consider using dcp_compress to summarize completed work phases, or dcp_prune to remove stale tool outputs from the <prunable-tools> list.
</dcp-nudge>
`.trim();

/**
 * Cooldown — shown right after a DCP tool was used to prevent loops
 */
export const COOLDOWN_PROMPT = `
<dcp-cooldown>
Context management action completed. Continue with your current task.
</dcp-cooldown>
`.trim();
