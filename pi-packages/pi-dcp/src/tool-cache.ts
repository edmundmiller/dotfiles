/**
 * Tool cache — tracks all tool calls and their results
 *
 * Syncs from context messages on every LLM call so the LLM
 * can reference tool calls by numeric ID for pruning/distillation.
 */

import type { AgentMessage } from "@mariozechner/pi-agent-core";
import { countTokens, extractMessageText } from "./tokens";

export interface ToolCacheEntry {
  /** Original tool call ID (e.g. toolu_01ABC) */
  callId: string;
  /** Tool name (read, write, edit, bash, etc.) */
  toolName: string;
  /** Tool parameters */
  parameters: Record<string, any>;
  /** Estimated token count of the result */
  tokenCount: number;
  /** Whether this tool produced an error */
  isError: boolean;
  /** Short identifier for display (e.g. file path, command) */
  paramKey: string;
}

export interface ToolCacheState {
  /** callId → entry */
  cache: Map<string, ToolCacheEntry>;
  /** Ordered list of callIds for numeric indexing */
  idList: string[];
  /** Set of callIds that have been pruned */
  prunedIds: Set<string>;
  /** callId → distillation text */
  distillations: Map<string, string>;
}

/**
 * Create empty tool cache state
 */
export function createToolCacheState(): ToolCacheState {
  return {
    cache: new Map(),
    idList: [],
    prunedIds: new Set(),
    distillations: new Map(),
  };
}

/**
 * Sync tool cache from current context messages.
 * Scans for assistant toolCall blocks and their matching toolResult messages.
 */
export function syncToolCache(
  state: ToolCacheState,
  messages: AgentMessage[],
  protectedTools: string[] = []
): void {
  // Build map of callId → toolResult for quick lookup
  const resultMap = new Map<string, AgentMessage>();
  for (const msg of messages) {
    if (msg.role === "toolResult" && msg.toolCallId) {
      resultMap.set(msg.toolCallId, msg);
    }
  }

  // Scan assistant messages for toolCall blocks
  for (const msg of messages) {
    if (msg.role !== "assistant" || !Array.isArray(msg.content)) continue;

    for (const block of msg.content) {
      if (!block || block.type !== "toolCall" || !block.id) continue;

      // Skip if already cached
      if (state.cache.has(block.id)) continue;

      const toolName = block.name || "unknown";
      const parameters = block.arguments || {};
      const result = resultMap.get(block.id);

      const tokenCount = result ? countTokens(extractMessageText(result)) : 0;
      const isError = result ? !!(result as any).isError : false;

      const entry: ToolCacheEntry = {
        callId: block.id,
        toolName,
        parameters,
        tokenCount,
        isError,
        paramKey: extractParamKey(toolName, parameters),
      };

      state.cache.set(block.id, entry);
      state.idList.push(block.id);
    }
  }
}

/**
 * Extract a human-readable key from tool parameters.
 * Used in the prunable-tools list so the LLM knows what each call did.
 */
export function extractParamKey(toolName: string, params: Record<string, any>): string {
  // File operations: use path
  if (params.path) return String(params.path);
  if (params.file_path) return String(params.file_path);

  // Bash: use command (truncated)
  if (params.command) {
    const cmd = String(params.command);
    return cmd.length > 60 ? cmd.slice(0, 57) + "..." : cmd;
  }

  // Search: use pattern/query
  if (params.pattern) return String(params.pattern);
  if (params.query) return String(params.query);
  if (params.regex) return String(params.regex);

  // Fallback: first string param
  for (const [, v] of Object.entries(params)) {
    if (typeof v === "string" && v.length > 0) {
      return v.length > 60 ? v.slice(0, 57) + "..." : v;
    }
  }

  return toolName;
}

/**
 * Get prunable entries (not already pruned, not protected, not too recent).
 * Returns entries with their numeric index for the LLM.
 *
 * @param skipRecent Number of most recent entries to exclude from the list.
 *   Prevents the model from pruning tool results it just received.
 */
export function getPrunableEntries(
  state: ToolCacheState,
  protectedTools: string[] = [],
  skipRecent: number = 5
): { numericId: number; entry: ToolCacheEntry }[] {
  const result: { numericId: number; entry: ToolCacheEntry }[] = [];

  // Don't show the last N entries as prunable — they're too fresh
  const cutoff = Math.max(0, state.idList.length - skipRecent);

  for (let i = 0; i < cutoff; i++) {
    const callId = state.idList[i];
    if (state.prunedIds.has(callId)) continue;

    const entry = state.cache.get(callId);
    if (!entry) continue;
    if (protectedTools.includes(entry.toolName)) continue;

    result.push({ numericId: i, entry });
  }

  return result;
}
