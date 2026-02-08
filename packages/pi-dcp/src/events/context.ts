/**
 * DCP Context Event Handler
 *
 * Handles the 'context' event which fires before each LLM call.
 * Two-layer pruning:
 * 1. Automatic rule-based pruning (dedup, superseded writes, errors, recency)
 * 2. LLM-driven pruning (apply prune/distill/compress decisions from tool calls)
 *
 * Also injects the <prunable-tools> list and nudges into context.
 */

import type { ContextEvent, ExtensionContext } from "@mariozechner/pi-coding-agent";
import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { DcpConfigWithPruneRuleObjects } from "../types";
import type { StatsTracker } from "../cmds/stats";
import type { ToolCacheState } from "../tool-cache";
import type { CompressSummary } from "../tools/compress";
import { applyPruningWorkflow } from "../workflow";
import { syncToolCache, getPrunableEntries } from "../tool-cache";
import { extractMessageText } from "../tokens";
import { extractToolUseIds, hasToolUse, hasToolResult } from "../metadata";
import {
  buildPrunableToolsList,
  NUDGE_PROMPT,
  COMPRESS_NUDGE_PROMPT,
  COOLDOWN_PROMPT,
} from "../prompts";
import { estimateContextTokens } from "../tokens";
import { getLogger } from "../logger";

export interface ContextEventHandlerOptions {
  config: DcpConfigWithPruneRuleObjects;
  statsTracker: StatsTracker;
  toolCacheState: ToolCacheState;
  compressSummaries: CompressSummary[];
  /** Tracks whether the last tool call was a DCP tool (for cooldown) */
  lastToolWasDcp: { value: boolean };
  /** Counter for nudge frequency */
  nudgeCounter: { value: number };
  /** Nudge every N turns */
  nudgeFrequency: number;
  /** Context token limit before compress nudge */
  contextLimit: number;
  /** Protected tool names that can't be pruned */
  protectedTools: string[];
}

const PRUNED_REPLACEMENT =
  "[Output removed to save context — information superseded or no longer needed]";

/**
 * Creates a context event handler that applies both automatic and LLM-driven pruning.
 */
export function createContextEventHandler(options: ContextEventHandlerOptions) {
  const {
    config,
    statsTracker,
    toolCacheState,
    compressSummaries,
    lastToolWasDcp,
    nudgeCounter,
    nudgeFrequency,
    contextLimit,
    protectedTools,
  } = options;

  return async (event: ContextEvent, ctx: ExtensionContext) => {
    const logger = getLogger();

    try {
      const originalCount = event.messages.length;

      // Layer 1: Automatic rule-based pruning
      let messages = applyPruningWorkflow(event.messages, config);

      // Layer 2: Sync tool cache from current messages
      syncToolCache(toolCacheState, messages, protectedTools);

      // Layer 2: Apply LLM-driven prune/distill/compress decisions
      messages = applyLlmDrivenPruning(messages, toolCacheState, compressSummaries, logger);

      // Layer 2.5: Final safety net — fix any orphaned tool pairs from layer 2
      messages = repairOrphanedToolPairsPostPruning(messages, logger);

      // Layer 3: Inject prunable-tools list and nudges
      injectContextInfo(
        messages,
        toolCacheState,
        lastToolWasDcp,
        nudgeCounter,
        nudgeFrequency,
        contextLimit,
        protectedTools,
        logger
      );

      // Update stats
      const prunedCount = originalCount - messages.length;
      statsTracker.totalPruned += prunedCount;
      statsTracker.totalProcessed += originalCount;

      // Increment nudge counter (reset happens when nudge is shown)
      nudgeCounter.value++;

      if (config.debug) {
        ctx.ui.notify(`[pi-dcp] Pruned ${prunedCount} / ${originalCount} messages`);
      }

      return { messages };
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      ctx.ui.notify(`[pi-dcp] Error in pruning workflow: ${errorMessage}`, "error");
      logger.error("Context event error", { error: errorMessage });
      return { messages: event.messages };
    }
  };
}

/**
 * Apply LLM-driven pruning decisions to messages.
 * Handles prune (remove/stub), distill (replace), and compress (summarize range).
 */
function applyLlmDrivenPruning(
  messages: AgentMessage[],
  state: ToolCacheState,
  compressSummaries: CompressSummary[],
  logger: ReturnType<typeof getLogger>
): AgentMessage[] {
  if (state.prunedIds.size === 0 && compressSummaries.length === 0) {
    return messages;
  }

  // Build anchor map for compress summaries
  const summaryByAnchor = new Map<string, string>();
  for (const cs of compressSummaries) {
    summaryByAnchor.set(cs.anchorCallId, cs.summary);
  }

  const injectedAnchors = new Set<string>();
  const result: AgentMessage[] = [];

  for (const msg of messages) {
    // Handle tool results
    if (msg.role === "toolResult" && msg.toolCallId) {
      if (state.prunedIds.has(msg.toolCallId)) {
        const distillation = state.distillations.get(msg.toolCallId);

        if (distillation) {
          // Replace with distillation (keeps pairing intact)
          result.push({
            ...msg,
            content: [{ type: "text", text: `[Distilled]\n${distillation}` }],
          } as any);
          continue;
        }

        // Use cache entry for tool name to stay consistent with assistant-side filtering
        const cacheEntry = state.cache.get(msg.toolCallId);
        const toolName = cacheEntry?.toolName || (msg as any).toolName || "unknown";

        // Write/edit: remove entirely (file system is source of truth)
        if (toolName === "write" || toolName === "edit") {
          continue;
        }

        // Other tools: replace with stub
        result.push({
          ...msg,
          content: [{ type: "text", text: PRUNED_REPLACEMENT }],
        } as any);
        continue;
      }

      // Compress anchor: inject summary INTO the tool_result instead of
      // inserting a separate user message (which breaks tool_use/tool_result adjacency)
      const anchorSummary = summaryByAnchor.get(msg.toolCallId);
      if (anchorSummary && !injectedAnchors.has(msg.toolCallId)) {
        result.push({
          ...msg,
          content: [{ type: "text", text: `[Compressed Summary]\n${anchorSummary}` }],
        } as any);
        injectedAnchors.add(msg.toolCallId);
        continue;
      }
    }

    // Handle assistant messages — remove toolCall blocks for pruned write/edit
    if (msg.role === "assistant" && Array.isArray(msg.content)) {
      const filtered = msg.content.filter((block: any) => {
        if (block.type !== "toolCall") return true;
        if (!state.prunedIds.has(block.id)) return true;

        const entry = state.cache.get(block.id);
        if (!entry) return true;
        return entry.toolName !== "write" && entry.toolName !== "edit";
      });

      if (filtered.length === 0) continue;
      if (filtered.length !== msg.content.length) {
        result.push({ ...msg, content: filtered } as any);
        continue;
      }
    }

    result.push(msg);
  }

  return result;
}

/**
 * Inject prunable-tools list and nudge prompts into the last user message.
 */
function injectContextInfo(
  messages: AgentMessage[],
  state: ToolCacheState,
  lastToolWasDcp: { value: boolean },
  nudgeCounter: { value: number },
  nudgeFrequency: number,
  contextLimit: number,
  protectedTools: string[],
  logger: ReturnType<typeof getLogger>
): void {
  const parts: string[] = [];

  if (lastToolWasDcp.value) {
    parts.push(COOLDOWN_PROMPT);
    lastToolWasDcp.value = false;
  } else {
    // Build prunable tools list
    const entries = getPrunableEntries(state, protectedTools);
    const prunableList = buildPrunableToolsList(entries);
    if (prunableList) {
      parts.push(prunableList);
    }

    // Check context size for compress nudge
    const totalTokens = estimateContextTokens(messages);
    if (totalTokens > contextLimit) {
      parts.push(COMPRESS_NUDGE_PROMPT);
      logger.info(`Context ~${totalTokens} tokens, exceeds limit ${contextLimit}`);
    } else if (nudgeCounter.value >= nudgeFrequency) {
      parts.push(NUDGE_PROMPT);
      nudgeCounter.value = 0;
    }
  }

  if (parts.length === 0) return;

  const combined = parts.join("\n\n");

  // Find last user message and append
  for (let i = messages.length - 1; i >= 0; i--) {
    const msg = messages[i] as any;
    if (msg.role === "user") {
      if (typeof msg.content === "string") {
        msg.content = msg.content + "\n\n" + combined;
      } else if (Array.isArray(msg.content)) {
        msg.content = [...msg.content, { type: "text", text: combined }];
      }
      return;
    }
  }
}

/**
 * Final safety net: remove orphaned tool_results and ensure every kept
 * tool_result has a corresponding tool_use in the messages.
 *
 * This runs AFTER all pruning layers (automatic + LLM-driven) to catch
 * orphans created by layer 2 that layer 1's repair couldn't anticipate.
 */
function repairOrphanedToolPairsPostPruning(
  messages: AgentMessage[],
  logger: ReturnType<typeof getLogger>
): AgentMessage[] {
  // Build set of all tool_use IDs present in assistant messages
  const availableToolUseIds = new Set<string>();
  for (const msg of messages) {
    if (hasToolUse(msg)) {
      for (const id of extractToolUseIds(msg)) {
        availableToolUseIds.add(id);
      }
    }
  }

  // Remove orphaned tool_results (those referencing non-existent tool_uses)
  const result: AgentMessage[] = [];
  let removedCount = 0;

  for (const msg of messages) {
    if (hasToolResult(msg)) {
      const ids = extractToolUseIds(msg);
      // If this tool_result references a tool_use that doesn't exist, remove it
      if (ids.length > 0 && ids.every((id) => !availableToolUseIds.has(id))) {
        removedCount++;
        logger.debug(`Post-repair: removing orphaned tool_result (tool_use_id: ${ids.join(", ")})`);
        continue;
      }
    }
    result.push(msg);
  }

  // Also check reverse: assistant tool_uses without matching tool_results
  // Build set of all tool_result IDs
  const availableToolResultIds = new Set<string>();
  for (const msg of result) {
    if (hasToolResult(msg)) {
      for (const id of extractToolUseIds(msg)) {
        availableToolResultIds.add(id);
      }
    }
  }

  // Filter assistant messages: remove orphaned toolCall blocks
  const finalResult: AgentMessage[] = [];
  for (const msg of result) {
    if (msg.role === "assistant" && Array.isArray(msg.content)) {
      const hasAnyToolCalls = msg.content.some((b: any) => b && b.type === "toolCall");
      if (!hasAnyToolCalls) {
        finalResult.push(msg);
        continue;
      }

      // Check if ALL toolCall blocks have matching tool_results
      const orphanedToolCalls = msg.content.filter(
        (b: any) => b && b.type === "toolCall" && b.id && !availableToolResultIds.has(b.id)
      );

      if (orphanedToolCalls.length > 0) {
        // Remove orphaned toolCall blocks
        const filtered = msg.content.filter(
          (b: any) => !(b && b.type === "toolCall" && b.id && !availableToolResultIds.has(b.id))
        );

        if (filtered.length === 0) {
          removedCount++;
          logger.debug(`Post-repair: removing assistant with only orphaned toolCalls`);
          continue;
        }

        finalResult.push({ ...msg, content: filtered } as any);
        logger.debug(
          `Post-repair: removed ${orphanedToolCalls.length} orphaned toolCall blocks from assistant`
        );
        continue;
      }
    }
    finalResult.push(msg);
  }

  if (removedCount > 0) {
    logger.info(`Post-repair: fixed ${removedCount} orphaned tool pair(s)`);
  }

  return finalResult;
}
