/**
 * Integration test to verify fix for toolCall/toolResult pairing issues
 *
 * Simulates the real-world scenario that caused 400 errors before the fix.
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

// Helpers
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

// Helpers to extract IDs from results
function collectToolCallIds(result: AgentMessage[]): Set<string> {
  const ids = new Set<string>();
  for (const msg of result) {
    if (msg.role === "assistant" && Array.isArray(msg.content)) {
      for (const part of msg.content) {
        if (part.type === "toolCall") ids.add(part.id);
      }
    }
  }
  return ids;
}

function collectToolResultIds(result: AgentMessage[]): string[] {
  const ids: string[] = [];
  for (const msg of result) {
    if (msg.role === "toolResult") ids.push(msg.toolCallId);
  }
  return ids;
}

describe("Fix Verification: Tool Use/Result Pairing", () => {
  beforeAll(() => {
    registerRule(deduplicationRule);
    registerRule(toolPairingRule);
    registerRule(recencyRule);
  });

  const realWorldMessages: AgentMessage[] = [
    user("Read the file"),
    assistant("I'll read it", [
      { id: "toolu_01VzLnitYpwspzkRMSc2bhfA", name: "read", args: { path: "test.txt" } },
    ]),
    toolResult("toolu_01VzLnitYpwspzkRMSc2bhfA", "read", "file contents"),
    assistant("Got it"),
    user("Read it again"),
    assistant("I'll read it", [
      { id: "toolu_01VzLnitYpwspzkRMSc2bhfA", name: "read", args: { path: "test.txt" } },
    ]),
    toolResult("toolu_01VzLnitYpwspzkRMSc2bhfA", "read", "file contents"),
  ];

  const strictConfig: DcpConfigWithPruneRuleObjects = {
    enabled: true,
    debug: false,
    rules: [deduplicationRule, toolPairingRule, recencyRule],
    keepRecentCount: 0,
  };

  test("should handle duplicate tool calls without breaking pairing", () => {
    const result = applyPruningWorkflow(realWorldMessages, strictConfig);

    const toolCallIds = collectToolCallIds(result);
    const toolResultIds = collectToolResultIds(result);

    for (const id of toolResultIds) {
      expect(toolCallIds.has(id)).toBe(true);
    }
  });

  test("should prune duplicate messages but maintain at least one valid pair", () => {
    const result = applyPruningWorkflow(realWorldMessages, strictConfig);

    expect(result.length).toBeLessThan(realWorldMessages.length);

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

  test("should prevent 400 API errors from orphaned toolResults", () => {
    const result = applyPruningWorkflow(realWorldMessages, strictConfig);

    const toolCallIds = collectToolCallIds(result);
    const orphaned: string[] = [];

    for (const msg of result) {
      if (msg.role === "toolResult") {
        if (!toolCallIds.has(msg.toolCallId)) {
          orphaned.push(msg.toolCallId);
        }
      }
    }

    expect(orphaned).toHaveLength(0);
  });

  test("should maintain message flow integrity", () => {
    const result = applyPruningWorkflow(realWorldMessages, strictConfig);

    expect(result.length).toBeGreaterThan(0);

    for (const msg of result) {
      expect(["user", "assistant", "toolResult"]).toContain(msg.role);
    }
  });

  test("should handle the specific error scenario from the real bug report", () => {
    const problematicMessages: AgentMessage[] = [
      user("Read the file"),
      assistant("I'll read it", [{ id: "toolu_ABC", name: "read", args: { path: "test.txt" } }]),
      toolResult("toolu_ABC", "read", "content"),
      // Duplicate pair that could cause orphaned result
      assistant("I'll read it", [{ id: "toolu_ABC", name: "read", args: { path: "test.txt" } }]),
      toolResult("toolu_ABC", "read", "content"),
    ];

    const result = applyPruningWorkflow(problematicMessages, strictConfig);

    const toolCallIds = collectToolCallIds(result);
    let allPairsValid = true;

    for (const msg of result) {
      if (msg.role === "toolResult") {
        if (!toolCallIds.has(msg.toolCallId)) allPairsValid = false;
      }
    }

    expect(allPairsValid).toBe(true);
  });
});
