/**
 * Test suite for tool-pairing rule
 *
 * Tests the tool pairing protection to ensure tool_use and tool_result pairs remain intact
 */

import { describe, test, expect, beforeAll } from "bun:test";
import { applyPruningWorkflow } from "../src/workflow";
import { registerRule } from "../src/registry";
import { deduplicationRule } from "../src/rules/deduplication";
import { toolPairingRule } from "../src/rules/tool-pairing";
import { recencyRule } from "../src/rules/recency";
import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { DcpConfigWithPruneRuleObjects } from "../src/types";

describe("Tool Pairing Protection", () => {
  beforeAll(() => {
    // Register rules
    registerRule(deduplicationRule);
    registerRule(toolPairingRule);
    registerRule(recencyRule);
  });

  const testMessages: AgentMessage[] = [
    // Message 0: User request
    {
      role: "user",
      content: "Please read the file",
    } as AgentMessage,

    // Message 1: Assistant with tool_use
    {
      role: "assistant",
      content: [
        { type: "text", text: "I'll read the file for you." },
        {
          type: "tool_use",
          id: "toolu_01ABC123",
          name: "read",
          input: { path: "test.txt" },
        },
      ],
    } as AgentMessage,

    // Message 2: Tool result
    {
      role: "user",
      content: [
        {
          type: "tool_result",
          tool_use_id: "toolu_01ABC123",
          content: "File contents here",
        },
      ],
    } as AgentMessage,

    // Message 3: Another assistant message (duplicate of message 1 - should be pruned)
    {
      role: "assistant",
      content: [
        { type: "text", text: "I'll read the file for you." },
        {
          type: "tool_use",
          id: "toolu_01ABC123",
          name: "read",
          input: { path: "test.txt" },
        },
      ],
    } as AgentMessage,

    // Message 4: Another tool result (duplicate - would be pruned but tool_use must stay)
    {
      role: "user",
      content: [
        {
          type: "tool_result",
          tool_use_id: "toolu_01ABC123",
          content: "File contents here",
        },
      ],
    } as AgentMessage,

    // Message 5: User message
    {
      role: "user",
      content: "Thanks!",
    } as AgentMessage,

    // Message 6: Assistant with different tool_use
    {
      role: "assistant",
      content: [
        { type: "text", text: "I'll write the file." },
        {
          type: "tool_use",
          id: "toolu_01XYZ789",
          name: "write",
          input: { path: "output.txt", content: "data" },
        },
      ],
    } as AgentMessage,

    // Message 7: Tool result for write
    {
      role: "user",
      content: [
        {
          type: "tool_result",
          tool_use_id: "toolu_01XYZ789",
          content: "File written successfully",
        },
      ],
    } as AgentMessage,
  ];

  const config: DcpConfigWithPruneRuleObjects = {
    enabled: true,
    debug: false, // Disable debug output in tests
    rules: [deduplicationRule, toolPairingRule, recencyRule],
    keepRecentCount: 3, // Keep last 3 messages
  };

  test("should reduce message count through pruning", () => {
    const result = applyPruningWorkflow(testMessages, config);
    expect(result.length).toBeLessThan(testMessages.length);
  });

  test("should maintain tool_use and tool_result pairing integrity", () => {
    const result = applyPruningWorkflow(testMessages, config);

    const toolUseIds = new Set<string>();
    const toolResultIds = new Set<string>();

    // Collect all tool_use IDs and tool_result IDs from result
    for (const msg of result) {
      if (Array.isArray(msg.content)) {
        for (const part of msg.content as any[]) {
          if (part?.type === "tool_use" && part.id) {
            toolUseIds.add(part.id);
          }
          if (part?.type === "tool_result" && part.tool_use_id) {
            toolResultIds.add(part.tool_use_id);
          }
        }
      }
    }

    // Every tool_result should have a matching tool_use
    for (const toolResultId of toolResultIds) {
      expect(toolUseIds.has(toolResultId)).toBe(true);
    }
  });

  test("should not create orphaned tool_results", () => {
    const result = applyPruningWorkflow(testMessages, config);

    let isValid = true;
    const toolUseIds = new Set<string>();

    for (const msg of result) {
      if (Array.isArray(msg.content)) {
        // First pass: collect all tool_use IDs
        for (const part of msg.content as any[]) {
          if (part?.type === "tool_use" && part.id) {
            toolUseIds.add(part.id);
          }
        }
      }
    }

    for (const msg of result) {
      if (Array.isArray(msg.content)) {
        // Second pass: verify all tool_results have matching tool_use
        for (const part of msg.content as any[]) {
          if (part?.type === "tool_result" && part.tool_use_id) {
            if (!toolUseIds.has(part.tool_use_id)) {
              isValid = false;
            }
          }
        }
      }
    }

    expect(isValid).toBe(true);
  });

  test("should preserve at least one tool_use/tool_result pair", () => {
    const result = applyPruningWorkflow(testMessages, config);

    let hasToolUse = false;
    let hasToolResult = false;

    for (const msg of result) {
      if (Array.isArray(msg.content)) {
        for (const part of msg.content as any[]) {
          if (part?.type === "tool_use") hasToolUse = true;
          if (part?.type === "tool_result") hasToolResult = true;
        }
      }
    }

    expect(hasToolUse).toBe(true);
    expect(hasToolResult).toBe(true);
  });

  test("should handle multiple different tool pairs correctly", () => {
    const result = applyPruningWorkflow(testMessages, config);

    const toolUseIds = new Set<string>();
    const toolResultIds = new Set<string>();

    for (const msg of result) {
      if (Array.isArray(msg.content)) {
        for (const part of msg.content as any[]) {
          if (part?.type === "tool_use" && part.id) {
            toolUseIds.add(part.id);
          }
          if (part?.type === "tool_result" && part.tool_use_id) {
            toolResultIds.add(part.tool_use_id);
          }
        }
      }
    }

    // Should have preserved both tool types
    expect(toolUseIds.size).toBeGreaterThan(0);
    expect(toolResultIds.size).toBeGreaterThan(0);

    // All tool_results should have matching tool_use
    for (const toolResultId of toolResultIds) {
      expect(toolUseIds.has(toolResultId)).toBe(true);
    }
  });
});
