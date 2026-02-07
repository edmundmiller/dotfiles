/**
 * Test suite for tool-pairing rule
 *
 * Tests the tool pairing protection to ensure toolCall (assistant) and
 * toolResult messages are never separated during pruning.
 */

import { describe, test, expect, beforeAll } from "bun:test";
import { applyPruningWorkflow } from "../src/workflow";
import { registerRule } from "../src/registry";
import { deduplicationRule } from "../src/rules/deduplication";
import { toolPairingRule } from "../src/rules/tool-pairing";
import { recencyRule } from "../src/rules/recency";
import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { AssistantMessage, ToolResultMessage, UserMessage } from "@mariozechner/pi-ai";
import type { DcpConfigWithPruneRuleObjects } from "../src/types";

// Helper to create pi-compatible test messages
function user(content: string, ts = Date.now()): UserMessage {
  return { role: "user", content, timestamp: ts };
}

function assistant(
  text: string,
  toolCalls: { id: string; name: string; args?: Record<string, any> }[] = [],
  ts = Date.now()
): AssistantMessage {
  const content: AssistantMessage["content"] = [{ type: "text", text }];
  for (const tc of toolCalls) {
    content.push({ type: "toolCall", id: tc.id, name: tc.name, arguments: tc.args ?? {} });
  }
  return {
    role: "assistant",
    content,
    api: "anthropic",
    provider: "anthropic",
    model: "test",
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: toolCalls.length ? "toolUse" : "stop",
    timestamp: ts,
  };
}

function toolResult(
  toolCallId: string,
  toolName: string,
  text: string,
  isError = false,
  ts = Date.now()
): ToolResultMessage {
  return {
    role: "toolResult",
    toolCallId,
    toolName,
    content: [{ type: "text", text }],
    isError,
    timestamp: ts,
  };
}

describe("Tool Pairing Protection", () => {
  beforeAll(() => {
    registerRule(deduplicationRule);
    registerRule(toolPairingRule);
    registerRule(recencyRule);
  });

  const testMessages: AgentMessage[] = [
    // 0: User request
    user("Please read the file"),
    // 1: Assistant with toolCall
    assistant("I'll read the file for you.", [
      { id: "toolu_01ABC123", name: "read", args: { path: "test.txt" } },
    ]),
    // 2: Tool result
    toolResult("toolu_01ABC123", "read", "File contents here"),
    // 3: Duplicate assistant (same tool call - should be pruned)
    assistant("I'll read the file for you.", [
      { id: "toolu_01ABC123", name: "read", args: { path: "test.txt" } },
    ]),
    // 4: Duplicate tool result
    toolResult("toolu_01ABC123", "read", "File contents here"),
    // 5: User message
    user("Thanks!"),
    // 6: Assistant with different toolCall
    assistant("I'll write the file.", [
      { id: "toolu_01XYZ789", name: "write", args: { path: "output.txt", content: "data" } },
    ]),
    // 7: Tool result for write
    toolResult("toolu_01XYZ789", "write", "File written successfully"),
  ];

  const config: DcpConfigWithPruneRuleObjects = {
    enabled: true,
    debug: false,
    rules: [deduplicationRule, toolPairingRule, recencyRule],
    keepRecentCount: 3,
  };

  test("should reduce message count through pruning", () => {
    const result = applyPruningWorkflow(testMessages, config);
    expect(result.length).toBeLessThan(testMessages.length);
  });

  test("should maintain toolCall and toolResult pairing integrity", () => {
    const result = applyPruningWorkflow(testMessages, config);

    const toolCallIds = new Set<string>();
    const toolResultIds = new Set<string>();

    for (const msg of result) {
      if (msg.role === "assistant" && Array.isArray(msg.content)) {
        for (const part of msg.content) {
          if (part.type === "toolCall") toolCallIds.add(part.id);
        }
      }
      if (msg.role === "toolResult") {
        toolResultIds.add(msg.toolCallId);
      }
    }

    // Every toolResult should have a matching toolCall
    for (const id of toolResultIds) {
      expect(toolCallIds.has(id)).toBe(true);
    }
  });

  test("should not create orphaned toolResults", () => {
    const result = applyPruningWorkflow(testMessages, config);

    const toolCallIds = new Set<string>();
    for (const msg of result) {
      if (msg.role === "assistant" && Array.isArray(msg.content)) {
        for (const part of msg.content) {
          if (part.type === "toolCall") toolCallIds.add(part.id);
        }
      }
    }

    let isValid = true;
    for (const msg of result) {
      if (msg.role === "toolResult") {
        if (!toolCallIds.has(msg.toolCallId)) isValid = false;
      }
    }

    expect(isValid).toBe(true);
  });

  test("should preserve at least one toolCall/toolResult pair", () => {
    const result = applyPruningWorkflow(testMessages, config);

    let hasToolCall = false;
    let hasToolResult = false;

    for (const msg of result) {
      if (msg.role === "assistant" && Array.isArray(msg.content)) {
        if (msg.content.some((p) => p.type === "toolCall")) hasToolCall = true;
      }
      if (msg.role === "toolResult") hasToolResult = true;
    }

    expect(hasToolCall).toBe(true);
    expect(hasToolResult).toBe(true);
  });

  // Regression: dotfiles-tmb9 — recency boundary splits duplicate pair
  // dedup marks both assistant[6] and toolResult[7] as pruned (identical to [1]/[2])
  // tool-pairing skips cascade because both already pruned
  // recency un-prunes toolResult[7] (inside window) but NOT assistant[6] (outside)
  // → orphaned tool_result → API 400
  test("should not orphan tool_result when recency boundary splits duplicate pair", () => {
    const msgs: AgentMessage[] = [
      // 0
      user("read the file"),
      // 1: original assistant+tool_use
      assistant("reading file", [{ id: "toolu_AAA", name: "read", args: { path: "f.txt" } }]),
      // 2: original tool_result
      toolResult("toolu_AAA", "read", "contents"),
      // 3
      user("do something else"),
      // 4
      assistant("ok", [{ id: "toolu_CCC", name: "write", args: { path: "g.txt", content: "x" } }]),
      // 5
      toolResult("toolu_CCC", "write", "done"),
      // 6: DUPLICATE assistant (same content as [1], different tool ID)
      assistant("reading file", [{ id: "toolu_BBB", name: "read", args: { path: "f.txt" } }]),
      // 7: DUPLICATE tool_result (same content as [2])
      toolResult("toolu_BBB", "read", "contents"),
      // 8
      user("thanks"),
    ];

    const cfg: DcpConfigWithPruneRuleObjects = {
      enabled: true,
      debug: false,
      rules: [deduplicationRule, toolPairingRule, recencyRule],
      keepRecentCount: 2, // protects indices 7,8 but NOT 6
    };

    const result = applyPruningWorkflow(msgs, cfg);

    // Collect kept tool IDs
    const keptToolUseIds = new Set<string>();
    const keptToolResultIds: string[] = [];
    for (const msg of result) {
      if (msg.role === "assistant" && Array.isArray(msg.content)) {
        for (const p of msg.content) {
          if (p.type === "toolCall") keptToolUseIds.add(p.id);
        }
      }
      if (msg.role === "toolResult") keptToolResultIds.push(msg.toolCallId);
    }

    // Every kept tool_result must have a matching kept tool_use
    for (const id of keptToolResultIds) {
      expect(keptToolUseIds.has(id)).toBe(true);
    }
  });

  test("should handle multiple different tool pairs correctly", () => {
    const result = applyPruningWorkflow(testMessages, config);

    const toolCallIds = new Set<string>();
    const toolResultIds = new Set<string>();

    for (const msg of result) {
      if (msg.role === "assistant" && Array.isArray(msg.content)) {
        for (const part of msg.content) {
          if (part.type === "toolCall") toolCallIds.add(part.id);
        }
      }
      if (msg.role === "toolResult") {
        toolResultIds.add(msg.toolCallId);
      }
    }

    expect(toolCallIds.size).toBeGreaterThan(0);
    expect(toolResultIds.size).toBeGreaterThan(0);

    for (const id of toolResultIds) {
      expect(toolCallIds.has(id)).toBe(true);
    }
  });
});
