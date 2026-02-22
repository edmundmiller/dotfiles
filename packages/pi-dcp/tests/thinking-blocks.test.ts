/**
 * Regression test for thinking/redacted_thinking block preservation
 *
 * Anthropic's API requires that thinking/redacted_thinking blocks in the
 * latest assistant message remain completely unmodified. DCP was causing
 * 400 errors by filtering toolCall blocks from assistant messages, which
 * modified the content array even when thinking blocks were present.
 *
 * Issue: dotfiles-qcqq, dotfiles-w1ae
 */

import { describe, test, expect } from "bun:test";
import { repairOrphanedToolPairsPostPruning } from "../src/events/context";
import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { AssistantMessage, ToolResultMessage, UserMessage } from "@mariozechner/pi-ai";

// Helpers
function user(content: string): UserMessage {
  return { role: "user", content, timestamp: Date.now() };
}

function assistantWithThinking(
  thinkingText: string,
  text: string,
  toolCalls: { id: string; name: string }[] = []
): AssistantMessage {
  const content: any[] = [
    { type: "thinking", thinking: thinkingText },
    { type: "text", text },
    ...toolCalls.map((tc) => ({ type: "toolCall", id: tc.id, name: tc.name, arguments: {} })),
  ];
  return {
    role: "assistant",
    content,
    api: "anthropic",
    provider: "anthropic",
    model: "claude-3-7-sonnet",
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: toolCalls.length ? "toolUse" : "stop",
    timestamp: Date.now(),
  };
}

function assistantWithRedactedThinking(
  text: string,
  toolCalls: { id: string; name: string }[] = []
): AssistantMessage {
  const content: any[] = [
    { type: "redacted_thinking", data: "encrypted-redacted-content" },
    { type: "text", text },
    ...toolCalls.map((tc) => ({ type: "toolCall", id: tc.id, name: tc.name, arguments: {} })),
  ];
  return {
    role: "assistant",
    content,
    api: "anthropic",
    provider: "anthropic",
    model: "claude-3-7-sonnet",
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: toolCalls.length ? "toolUse" : "stop",
    timestamp: Date.now(),
  };
}

function toolResult(toolCallId: string, toolName: string, text: string): ToolResultMessage {
  return {
    role: "toolResult",
    toolCallId,
    toolName,
    content: [{ type: "text", text }],
    isError: false,
    timestamp: Date.now(),
  };
}

const mockLogger = {
  debug: () => {},
  info: () => {},
  warn: () => {},
  error: () => {},
} as any;

describe("regression: thinking blocks in latest assistant message", () => {
  test("repairOrphanedToolPairs: latest assistant with thinking blocks is not modified", () => {
    // Latest assistant has thinking blocks + toolCall with NO matching tool_result
    // (orphaned by a prior DCP prune). Without the fix, the repair would filter
    // out the orphaned toolCall block, modifying content — causing a 400 error.
    const messages: AgentMessage[] = [
      user("Do something"),
      // Earlier assistant with resolved tool pair (not the latest)
      {
        role: "assistant",
        content: [
          { type: "text", text: "Let me read" },
          { type: "toolCall", id: "tc_old", name: "Read", arguments: {} },
        ],
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
        stopReason: "toolUse",
        timestamp: Date.now(),
      } as AssistantMessage,
      toolResult("tc_old", "Read", "file contents"),
      user("Now do something else"),
      // Latest assistant: has thinking block + orphaned toolCall (no matching tool_result)
      assistantWithThinking("Let me think about this...", "I'll use a tool", [
        { id: "tc_latest_orphan", name: "Bash" },
      ]),
      // Note: NO toolResult for tc_latest_orphan (simulates it being pruned by DCP)
    ];

    const result = repairOrphanedToolPairsPostPruning(messages, mockLogger);

    // The latest assistant message should NOT be modified — pass through as-is
    const latestAssistant = result.filter((m) => m.role === "assistant").at(-1) as AssistantMessage;
    expect(latestAssistant).toBeDefined();

    // thinking block must still be present
    const blocks = latestAssistant.content as any[];
    expect(blocks.some((b: any) => b.type === "thinking")).toBe(true);

    // toolCall block must still be present (not stripped out)
    expect(blocks.some((b: any) => b.type === "toolCall" && b.id === "tc_latest_orphan")).toBe(
      true
    );

    // content array must be the exact same reference (no new object created)
    const originalMsg = messages[4] as AssistantMessage;
    expect(latestAssistant.content).toBe(originalMsg.content);
  });

  test("repairOrphanedToolPairs: latest assistant with redacted_thinking blocks is not modified", () => {
    const messages: AgentMessage[] = [
      user("Do something"),
      assistantWithRedactedThinking("I'll help", [{ id: "tc_orphan", name: "Read" }]),
      // No tool_result for tc_orphan
    ];

    const result = repairOrphanedToolPairsPostPruning(messages, mockLogger);
    const latestAssistant = result.filter((m) => m.role === "assistant").at(-1) as AssistantMessage;

    // redacted_thinking block must survive
    const blocks = latestAssistant.content as any[];
    expect(blocks.some((b: any) => b.type === "redacted_thinking")).toBe(true);
    expect(blocks.some((b: any) => b.type === "toolCall")).toBe(true);

    // Same reference — untouched
    expect(latestAssistant.content).toBe((messages[1] as AssistantMessage).content);
  });

  test("repairOrphanedToolPairs: earlier assistant without thinking blocks CAN be modified", () => {
    // An earlier (non-latest) assistant with orphaned toolCalls should still be cleaned up
    const messages: AgentMessage[] = [
      user("Step 1"),
      {
        role: "assistant",
        content: [
          { type: "text", text: "earlier" },
          { type: "toolCall", id: "tc_orphan_early", name: "Bash", arguments: {} },
        ],
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
        stopReason: "toolUse",
        timestamp: Date.now() - 1000,
      } as AssistantMessage,
      // No tool_result for tc_orphan_early
      user("Step 2"),
      // Latest assistant — no thinking blocks, no orphaned tool calls
      {
        role: "assistant",
        content: [{ type: "text", text: "done" }],
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
        stopReason: "stop",
        timestamp: Date.now(),
      } as AssistantMessage,
    ];

    const result = repairOrphanedToolPairsPostPruning(messages, mockLogger);

    // Earlier assistant had text + orphaned toolCall — toolCall stripped, text kept
    const assistants = result.filter((m) => m.role === "assistant") as AssistantMessage[];
    expect(assistants).toHaveLength(2);

    // Earlier assistant: orphaned toolCall block removed, text preserved
    const earlyBlocks = assistants[0].content as any[];
    expect(earlyBlocks.some((b: any) => b.type === "toolCall")).toBe(false);
    expect(earlyBlocks.some((b: any) => b.text === "earlier")).toBe(true);

    // Latest assistant: unchanged
    expect((assistants[1].content as any[])[0].text).toBe("done");
  });
});
