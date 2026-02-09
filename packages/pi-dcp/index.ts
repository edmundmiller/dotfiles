/**
 * Pi-DCP: Dynamic Context Pruning Extension
 *
 * Two-layer context management:
 * 1. Automatic rule-based pruning (dedup, superseded writes, errors, recency)
 * 2. LLM-driven tools (prune, distill, compress) the model can call explicitly
 *
 * Architecture:
 * - Rules run automatically on every context event
 * - Tools give the LLM agency to make intelligent pruning decisions
 * - <prunable-tools> list shows the LLM what can be managed
 * - Nudges remind the LLM to use context management periodically
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import type { StatsTracker } from "./src/cmds/stats";
import { loadConfig } from "./src/config";
import { createStatsCommand } from "./src/cmds/stats";
import { createDebugCommand } from "./src/cmds/debug";
import { createToggleCommand } from "./src/cmds/toggle";
import { createRecentCommand } from "./src/cmds/recent";
import { createInitCommand } from "./src/cmds/init";
import { createToolsExpandedCommand } from "./src/cmds/tools-expanded";
import { dcpLogsCommand } from "./src/cmds/logs";
import { createContextEventHandler } from "./src/events/context";
import { createSessionStartEventHandler } from "./src/events/sessionStart";
import { getLogger, LogLevel } from "./src/logger";

// Register all built-in rules on import
import { registerRule } from "./src/registry";
import { deduplicationRule } from "./src/rules/deduplication";
import { supersededWritesRule } from "./src/rules/superseded-writes";
import { errorPurgingRule } from "./src/rules/error-purging";
import { toolPairingRule } from "./src/rules/tool-pairing";
import { recencyRule } from "./src/rules/recency";
import { DcpConfig, DcpConfigWithPruneRuleObjects } from "./src/types";

// Tool cache and LLM-driven tools
import { createToolCacheState, type ToolCacheState } from "./src/tool-cache";
import { type CompressSummary } from "./src/tools/compress";
import {
  pruneToolName,
  pruneToolDescription,
  pruneToolParameters,
  executePrune,
} from "./src/tools/prune";
import {
  distillToolName,
  distillToolDescription,
  distillToolParameters,
  executeDistill,
} from "./src/tools/distill";
import {
  compressToolName,
  compressToolDescription,
  compressToolParameters,
  executeCompress,
} from "./src/tools/compress";
import { SYSTEM_PROMPT } from "./src/prompts";

// Register rules in order
registerRule(deduplicationRule);
registerRule(supersededWritesRule);
registerRule(errorPurgingRule);
registerRule(toolPairingRule);
registerRule(recencyRule);

/** DCP tool names for cooldown detection */
const DCP_TOOL_NAMES = [pruneToolName, distillToolName, compressToolName];

/** Default protected tools that shouldn't be pruned */
const DEFAULT_PROTECTED_TOOLS = ["dcp_prune", "dcp_distill", "dcp_compress"];

/** Custom entry types for state persistence */
const ENTRY_TYPE_PRUNE = "dcp-prune";
const ENTRY_TYPE_DISTILL = "dcp-distill";
const ENTRY_TYPE_COMPRESS = "dcp-compress";

export default async function (pi: ExtensionAPI) {
  const config = await loadConfig(pi);

  const logger = getLogger({
    minLevel: config.debug ? LogLevel.DEBUG : LogLevel.INFO,
    enableConsole: false,
  });

  logger.info("pi-dcp extension loaded", {
    enabled: config.enabled,
    debug: config.debug,
    rules: config.rules.length,
  });

  // Always-available commands
  pi.registerCommand("dcp-init", createInitCommand());
  pi.registerCommand("dcp-toggle", createToggleCommand(config));
  pi.registerCommand("dcp-tools", createToolsExpandedCommand());

  if (!config.enabled) return;

  // Shared state
  const statsTracker: StatsTracker = { totalPruned: 0, totalProcessed: 0 };
  const toolCacheState: ToolCacheState = createToolCacheState();
  const compressSummaries: CompressSummary[] = [];
  const lastToolWasDcp = { value: false };
  const nudgeCounter = { value: 0 };

  // Config for LLM-driven features
  const nudgeFrequency = 15;
  const contextLimit = 120_000;
  const protectedTools = [...DEFAULT_PROTECTED_TOOLS];

  // Register commands
  pi.registerCommand("dcp-debug", createDebugCommand(config));
  pi.registerCommand("dcp-recent", createRecentCommand(config));
  pi.registerCommand("dcp-stats", createStatsCommand(statsTracker, config.rules.length));
  pi.registerCommand("dcp-logs", dcpLogsCommand);

  // Register LLM-callable tools
  pi.registerTool({
    name: pruneToolName,
    label: "DCP Prune",
    description: pruneToolDescription,
    parameters: pruneToolParameters,
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = executePrune(toolCacheState, params, protectedTools);
      lastToolWasDcp.value = true;
      nudgeCounter.value = 0;

      pi.appendEntry(ENTRY_TYPE_PRUNE, {
        prunedIds: Array.from(toolCacheState.prunedIds),
      });

      return {
        content: [{ type: "text", text: result.message }],
        details: { pruned: result.pruned, skipped: result.skipped },
      };
    },
  });

  pi.registerTool({
    name: distillToolName,
    label: "DCP Distill",
    description: distillToolDescription,
    parameters: distillToolParameters,
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = executeDistill(toolCacheState, params, protectedTools);
      lastToolWasDcp.value = true;
      nudgeCounter.value = 0;

      pi.appendEntry(ENTRY_TYPE_DISTILL, {
        prunedIds: Array.from(toolCacheState.prunedIds),
        distillations: Object.fromEntries(toolCacheState.distillations),
      });

      return {
        content: [{ type: "text", text: result.message }],
        details: { distilled: result.distilled, skipped: result.skipped },
      };
    },
  });

  pi.registerTool({
    name: compressToolName,
    label: "DCP Compress",
    description: compressToolDescription,
    parameters: compressToolParameters,
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = executeCompress(toolCacheState, compressSummaries, params, protectedTools);
      lastToolWasDcp.value = true;
      nudgeCounter.value = 0;

      if ("error" in result) {
        return {
          content: [{ type: "text", text: `Error: ${result.error}` }],
          details: { error: result.error },
        };
      }

      pi.appendEntry(ENTRY_TYPE_COMPRESS, { summaries: compressSummaries });

      return {
        content: [{ type: "text", text: result.message }],
        details: { compressed: result.compressed, topic: params.topic },
      };
    },
  });

  // Inject system prompt with context management instructions
  pi.on("before_agent_start", async (event) => {
    return {
      systemPrompt: event.systemPrompt + "\n\n" + SYSTEM_PROMPT,
    };
  });

  // Context event: two-layer pruning + injection
  pi.on(
    "context",
    createContextEventHandler({
      config,
      statsTracker,
      toolCacheState,
      compressSummaries,
      lastToolWasDcp,
      nudgeCounter,
      nudgeFrequency,
      contextLimit,
      protectedTools,
    })
  );

  // Session start: restore persisted state
  pi.on("session_start", async (_event, ctx) => {
    try {
      for (const entry of ctx.sessionManager.getEntries()) {
        if (entry.type !== "custom") continue;

        if (entry.customType === ENTRY_TYPE_PRUNE && entry.data) {
          const data = entry.data as { prunedIds: string[] };
          for (const id of data.prunedIds) toolCacheState.prunedIds.add(id);
        } else if (entry.customType === ENTRY_TYPE_DISTILL && entry.data) {
          const data = entry.data as {
            prunedIds: string[];
            distillations: Record<string, string>;
          };
          for (const id of data.prunedIds) toolCacheState.prunedIds.add(id);
          for (const [k, v] of Object.entries(data.distillations)) {
            toolCacheState.distillations.set(k, v);
          }
        } else if (entry.customType === ENTRY_TYPE_COMPRESS && entry.data) {
          const data = entry.data as { summaries: CompressSummary[] };
          compressSummaries.push(...data.summaries);
          for (const cs of data.summaries) {
            for (const id of cs.compressedIds) toolCacheState.prunedIds.add(id);
          }
        }
      }

      if (toolCacheState.prunedIds.size > 0) {
        logger.info(`Restored DCP state: ${toolCacheState.prunedIds.size} pruned IDs`);
      }
    } catch (e) {
      logger.error("Failed to restore DCP state", {
        error: e instanceof Error ? e.message : String(e),
      });
    }
  });

  // Session start: show active rules
  pi.on("session_start", createSessionStartEventHandler({ config }));

  // Session compact: reset LLM-driven state (rules are stateless)
  pi.on("session_compact", async () => {
    toolCacheState.cache.clear();
    toolCacheState.idList.length = 0;
    toolCacheState.prunedIds.clear();
    toolCacheState.distillations.clear();
    compressSummaries.length = 0;
    nudgeCounter.value = 0;
    lastToolWasDcp.value = false;
    logger.info("Session compacted — DCP state reset");
  });
}
