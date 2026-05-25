/**
 * Message metadata utilities
 */

import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { MessageWithMetadata } from "./types";

/**
 * Wrap an AgentMessage with metadata container
 */
export function createMessageWithMetadata(message: AgentMessage): MessageWithMetadata {
  return {
    message,
    metadata: {},
  };
}

/**
 * Create a stable hash of message content for deduplication
 */
export function hashMessage(message: AgentMessage): string {
  // Create a stable string representation of the message content
  let content = "";

  // toolResult messages: include toolCallId and toolName for uniqueness
  if (message.role === "toolResult") {
    content = `[toolResult:${(message as any).toolCallId || "?"}:${(message as any).toolName || "?"}]`;
  }

  if ("content" in message) {
    if (typeof message.content === "string") {
      content += message.content;
    } else if (Array.isArray(message.content)) {
      content += message.content
        .map((part: any) => {
          // Handle undefined or malformed parts
          if (!part || typeof part !== "object") return "";

          if (part.type === "text") return part.text || "";
          if (part.type === "image") return `[image:${part.source?.type || "unknown"}]`;
          // Pi uses "toolCall" (not "tool_use") for assistant tool invocations
          if (part.type === "toolCall") {
            const args = part.arguments ? JSON.stringify(part.arguments) : "";
            return `[tool:${part.id || "?"}:${part.name || "unknown"}:${args}]`;
          }
          // Legacy API format
          if (part.type === "tool_use") {
            const input = part.input ? JSON.stringify(part.input) : "";
            return `[tool:${part.id || "?"}:${part.name || "unknown"}:${input}]`;
          }
          if (part.type === "tool_result") return `[result:${part.tool_use_id || "unknown"}]`;
          return "";
        })
        .join("");
    }
  }

  // Simple hash function (djb2)
  let hash = 5381;
  for (let i = 0; i < content.length; i++) {
    hash = (hash * 33) ^ content.charCodeAt(i);
  }
  return hash.toString(36);
}

/**
 * Extract file path from write/edit tool result
 */
export function extractFilePath(message: AgentMessage): string | null {
  if (message.role !== "toolResult") return null;

  const toolName = (message as any).toolName;
  if (toolName !== "write" && toolName !== "edit") return null;

  // Try to extract from details
  const details = (message as any).details;
  if (details?.path) return details.path;
  if (details?.file) return details.file;

  return null;
}

/**
 * Check if message is an error
 */
export function isErrorMessage(message: AgentMessage): boolean {
  if (message.role === "toolResult") {
    return !!(message as any).isError;
  }

  // Check content for error patterns
  if ("content" in message) {
    const content = typeof message.content === "string" ? message.content : "";
    const errorPatterns = [/error:/i, /failed:/i, /exception:/i, /\[error\]/i];
    return errorPatterns.some((pattern) => pattern.test(content));
  }

  return false;
}

/**
 * Check if two messages represent the same operation (for error resolution tracking)
 */
export function isSameOperation(msg1: AgentMessage, msg2: AgentMessage): boolean {
  if (msg1.role !== "toolResult" || msg2.role !== "toolResult") return false;

  const tool1 = (msg1 as any).toolName;
  const tool2 = (msg2 as any).toolName;

  if (tool1 !== tool2) return false;

  // For file operations, check if same file
  const path1 = extractFilePath(msg1);
  const path2 = extractFilePath(msg2);

  if (path1 && path2) {
    return path1 === path2;
  }

  // For other operations, compare content directly (not hashMessage,
  // which includes toolCallId and would never match across different calls)
  return hashContentOnly(msg1) === hashContentOnly(msg2);
}

/**
 * Hash only the content of a message, ignoring identity fields like toolCallId.
 * Used for comparing whether two operations did the same thing (error resolution).
 */
function hashContentOnly(message: AgentMessage): string {
  let content = "";
  if ("content" in message) {
    if (typeof message.content === "string") {
      content = message.content;
    } else if (Array.isArray(message.content)) {
      content = message.content
        .map((part: any) => {
          if (!part || typeof part !== "object") return "";
          if (part.type === "text") return part.text || "";
          return "";
        })
        .join("");
    }
  }
  let hash = 5381;
  for (let i = 0; i < content.length; i++) {
    hash = (hash * 33) ^ content.charCodeAt(i);
  }
  return hash.toString(36);
}

/**
 * Extract tool IDs from a message.
 * - For assistant messages: extracts toolCall IDs from content blocks
 * - For toolResult messages: extracts the toolCallId
 */
export function extractToolUseIds(message: AgentMessage): string[] {
  const ids: string[] = [];

  // toolResult messages have a toolCallId field
  if (message.role === "toolResult") {
    if (message.toolCallId) {
      ids.push(message.toolCallId);
    }
    return ids;
  }

  // assistant messages have toolCall content blocks
  if (message.role === "assistant" && Array.isArray(message.content)) {
    for (const part of message.content) {
      if (part && typeof part === "object" && part.type === "toolCall" && part.id) {
        ids.push(part.id);
      }
    }
  }

  return ids;
}

/**
 * Check if a message contains toolCall blocks (assistant messages)
 */
export function hasToolUse(message: AgentMessage): boolean {
  if (message.role === "assistant" && Array.isArray(message.content)) {
    return message.content.some(
      (part) => part && typeof part === "object" && part.type === "toolCall"
    );
  }
  return false;
}

/**
 * Check if a message is a tool result
 */
export function hasToolResult(message: AgentMessage): boolean {
  return message.role === "toolResult";
}
