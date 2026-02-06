/**
 * Pi-DCP: Dynamic Context Pruning Extension
 *
 * Intelligently prunes conversation context to optimize token usage
 * while preserving conversation coherence.
 *
 * Features:
 * - Deduplication: Remove duplicate tool outputs
 * - Superseded writes: Remove older file versions
 * - Error purging: Remove resolved errors
 * - Recency protection: Always keep recent messages
 *
 * Architecture:
 * - Prepare phase: Rules annotate message metadata
 * - Process phase: Rules make pruning decisions
 * - Filter phase: Remove pruned messages
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

// Register in order they should typically be applied
registerRule(deduplicationRule);
registerRule(supersededWritesRule);
registerRule(errorPurgingRule);
// Tool-pairing MUST run before recency to ensure pairs are intact
registerRule(toolPairingRule);
// Recency should be LAST to override other decisions
registerRule(recencyRule);

export default async function (pi: ExtensionAPI) {
  const config = await loadConfig(pi);

  // Initialize logger with config-based settings
  const logger = getLogger({
    minLevel: config.debug ? LogLevel.DEBUG : LogLevel.INFO,
    enableConsole: false, // Don't duplicate to console (not visible in pi anyway)
  });

  logger.info("pi-dcp extension loaded", {
    enabled: config.enabled,
    debug: config.debug,
    rules: config.rules.length,
  });

  pi.registerCommand("dcp-init", createInitCommand());
  pi.registerCommand("dcp-toggle", createToggleCommand(config));
  pi.registerCommand("dcp-tools", createToolsExpandedCommand());

  if (!config.enabled) {
    return; // Exit early if extension is disabled
  }

  // Track stats across session
  const statsTracker: StatsTracker = {
    totalPruned: 0,
    totalProcessed: 0,
  };

  // Register commands
  pi.registerCommand("dcp-debug", createDebugCommand(config));
  pi.registerCommand("dcp-recent", createRecentCommand(config));
  pi.registerCommand("dcp-stats", createStatsCommand(statsTracker, config.rules.length));
  pi.registerCommand("dcp-logs", dcpLogsCommand);

  // Hook into context event (before each LLM call)
  pi.on("context", createContextEventHandler({ config, statsTracker }));
  pi.on("session_start", createSessionStartEventHandler({ config }));
}
