/**
 * Core type definitions for Pi-DCP
 */

import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

/**
 * Message with pruning metadata attached
 */
export interface MessageWithMetadata {
  /** Original message from pi */
  message: AgentMessage;
  /** Pruning metadata annotated by rules */
  metadata: MessageMetadata;
}

/**
 * Metadata attached to messages during prepare/process phases
 */
export interface MessageMetadata {
  /** Content hash for deduplication */
  hash?: string;
  /** File path for superseded writes tracking */
  filePath?: string;
  /** File content version for superseded writes */
  fileVersion?: string;
  /** Whether message is an error */
  isError?: boolean;
  /** Whether error was resolved by later success */
  errorResolved?: boolean;
  /** Recency score (distance from end) */
  recencyScore?: number;
  /** Whether protected by recency rule */
  protectedByRecency?: boolean;
  /** Final decision: should this message be pruned? */
  shouldPrune?: boolean;
  /** Reason for pruning (for debugging) */
  pruneReason?: string;
  /** Extensible: custom rule metadata */
  [key: string]: any;
}

/**
 * Context provided to prepare phase
 */
export interface PrepareContext {
  /** All messages being prepared */
  messages: MessageWithMetadata[];
  /** Current message index */
  index: number;
  /** Extension configuration */
  config: DcpConfigWithPruneRuleObjects;
}

/**
 * Context provided to process phase
 */
export interface ProcessContext {
  /** All messages with metadata from prepare phase */
  messages: MessageWithMetadata[];
  /** Current message index */
  index: number;
  /** Extension configuration */
  config: DcpConfigWithPruneRuleObjects;
}

/**
 * Pruning rule definition
 */
export interface PruneRule {
  /** Unique rule identifier */
  name: string;
  /** Human-readable description */
  description?: string;
  /** Prepare phase: annotate metadata */
  prepare?: (msg: MessageWithMetadata, context: PrepareContext) => void;
  /** Process phase: make pruning decisions */
  process?: (msg: MessageWithMetadata, context: ProcessContext) => void;
}
export const isPruneRuleObject = (obj: unknown): obj is PruneRule => {
  return (
    typeof obj === "object" &&
    obj !== null &&
    "name" in obj &&
    ("prepare" in obj || "process" in obj) &&
    typeof (obj as any).name === "string" &&
    (typeof (obj as any).prepare === "function" || typeof (obj as any).process === "function")
  );
};

/**
 * Extension configuration
 */
export interface DcpConfig {
  /** Master enable/disable toggle */
  enabled?: boolean;
  /** Enable debug logging */
  debug?: boolean;
  /** Always keep last N messages */
  keepRecentCount: number;
  /** Optional log directory override */
  logDir?: string;
}
export type DcpConfigWithPruneRuleObjects = DcpConfig & {
  rules: PruneRule[];
};
export type DcpConfigWithRuleRefs = DcpConfig & {
  rules: (string | PruneRule)[];
};

export type CommandDefinition = Parameters<ExtensionAPI["registerCommand"]>[1];

/**
 * Stats tracker for pruning statistics
 */
export interface StatsTracker {
  /** Total messages pruned */
  totalPruned: number;
  /** Total messages processed */
  totalProcessed: number;
}
