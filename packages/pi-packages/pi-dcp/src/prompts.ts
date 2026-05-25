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

You operate in a context-constrained environment. PROACTIVELY manage context to avoid context rot — stale outputs accumulating and degrading your performance. This is CRITICAL.

### Tools

- **dcp_distill**: Condense tool outputs into high-fidelity knowledge nuggets. Your distillation must be comprehensive — capture technical details (symbols, signatures, logic, constraints) such that raw output is no longer needed. Distill is the PREFERRED tool: it preserves gained insights while freeing space. Use when raw info isn't needed but the knowledge is valuable.

- **dcp_compress**: Squash a contiguous range of conversation into a technical summary. This is a sledgehammer — it replaces everything in the range (user/assistant messages, tool I/O). Use at natural phase boundaries, not preemptively. Your summary MUST be specific enough that NO AMBIGUITY remains about what was done, found, or decided.

- **dcp_prune**: Remove tool outputs entirely with NO preservation. Last resort. Only prune outputs you're certain are irrelevant or superseded. Never prune outputs you may need later. Write/edit outputs are safe to prune since the filesystem is source of truth.

### Timing

Manage context at the START of a new turn (after receiving a user message), not at the END of your previous turn. At turn start you have fresh signal about what's needed next — you can better judge what's relevant vs noise from prior work.

### Rules

- NEVER call ONLY context management tools in a response — always parallelize with task-continuation tools (read, edit, bash)
- Prefer distill over prune when information has value worth preserving
- Use compress at natural conversation breakpoints, not mid-task
- The <prunable-tools> list shows what's available to manage — if none is present, don't attempt to prune
- Be respectful of API usage — manage methodically as you work, not in bulk cleanup bursts
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
 * Dumb zone nudge — triggered by pi-dumb-zone signal at ≥40% context usage.
 * More urgent than COMPRESS_NUDGE. Tells the LLM to act now.
 */
export const DUMB_ZONE_NUDGE_PROMPT = `
<dcp-nudge priority="critical">
⚠️ Context at {pct}% — you're in the dumb zone. You should prune stale tool outputs or compress completed work phases NOW using dcp_prune, dcp_distill, or dcp_compress. Check the <prunable-tools> list above.
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
