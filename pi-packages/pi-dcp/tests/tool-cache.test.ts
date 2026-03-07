/**
 * Tests for tool cache sync and prunable entries
 */

import { describe, test, expect } from "bun:test";
import {
  createToolCacheState,
  syncToolCache,
  getPrunableEntries,
  extractParamKey,
} from "../src/tool-cache";
import type { AgentMessage } from "@mariozechner/pi-agent-core";
import type { AssistantMessage, ToolResultMessage } from "@mariozechner/pi-ai";

function assistant(
  text: string,
  toolCalls: { id: string; name: string; args?: Record<string, any> }[] = []
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
    timestamp: Date.now(),
  };
}

function toolResult(
  callId: string,
  toolName: string,
  text: string,
  isError = false
): ToolResultMessage {
  return {
    role: "toolResult",
    toolCallId: callId,
    toolName,
    content: [{ type: "text", text }],
    isError,
    timestamp: Date.now(),
  };
}

describe("Tool Cache", () => {
  test("syncs tool calls and results from messages", () => {
    const state = createToolCacheState();
    const messages: AgentMessage[] = [
      assistant("reading file", [{ id: "toolu_A", name: "read", args: { path: "src/index.ts" } }]),
      toolResult("toolu_A", "read", "file contents here"),
      assistant("running command", [{ id: "toolu_B", name: "bash", args: { command: "ls -la" } }]),
      toolResult("toolu_B", "bash", "drwxr-xr-x ..."),
    ];

    syncToolCache(state, messages);

    expect(state.cache.size).toBe(2);
    expect(state.idList).toEqual(["toolu_A", "toolu_B"]);

    const entryA = state.cache.get("toolu_A")!;
    expect(entryA.toolName).toBe("read");
    expect(entryA.paramKey).toBe("src/index.ts");
    expect(entryA.tokenCount).toBeGreaterThan(0);

    const entryB = state.cache.get("toolu_B")!;
    expect(entryB.toolName).toBe("bash");
    expect(entryB.paramKey).toBe("ls -la");
  });

  test("does not duplicate on re-sync", () => {
    const state = createToolCacheState();
    const messages: AgentMessage[] = [
      assistant("reading", [{ id: "toolu_A", name: "read", args: { path: "f.txt" } }]),
      toolResult("toolu_A", "read", "contents"),
    ];

    syncToolCache(state, messages);
    syncToolCache(state, messages);

    expect(state.cache.size).toBe(1);
    expect(state.idList.length).toBe(1);
  });

  test("tracks error tool results", () => {
    const state = createToolCacheState();
    const messages: AgentMessage[] = [
      assistant("reading", [{ id: "toolu_A", name: "read", args: { path: "missing.txt" } }]),
      toolResult("toolu_A", "read", "File not found", true),
    ];

    syncToolCache(state, messages);
    expect(state.cache.get("toolu_A")!.isError).toBe(true);
  });

  test("getPrunableEntries excludes pruned and protected", () => {
    const state = createToolCacheState();
    const messages: AgentMessage[] = [
      assistant("a", [{ id: "toolu_A", name: "read", args: { path: "a.txt" } }]),
      toolResult("toolu_A", "read", "aaa"),
      assistant("b", [{ id: "toolu_B", name: "dcp_prune", args: { ids: ["0"] } }]),
      toolResult("toolu_B", "dcp_prune", "pruned"),
      assistant("c", [{ id: "toolu_C", name: "write", args: { path: "b.txt" } }]),
      toolResult("toolu_C", "write", "done"),
    ];

    syncToolCache(state, messages);
    state.prunedIds.add("toolu_A");

    // skipRecent=0 to test filtering logic without recency guard
    const entries = getPrunableEntries(state, ["dcp_prune"], 0);
    expect(entries.length).toBe(1);
    expect(entries[0].entry.toolName).toBe("write");
    expect(entries[0].numericId).toBe(2);
  });

  test("getPrunableEntries skips recent entries by default", () => {
    const state = createToolCacheState();
    const messages: AgentMessage[] = [];

    // Create 8 tool calls so some are old enough to be prunable
    for (let i = 0; i < 8; i++) {
      const id = `toolu_${i}`;
      messages.push(
        assistant(`call ${i}`, [{ id, name: "read", args: { path: `file${i}.txt` } }]),
        toolResult(id, "read", `content ${i}`)
      );
    }

    syncToolCache(state, messages);

    // Default skipRecent=5: only first 3 should be prunable
    const entries = getPrunableEntries(state, []);
    expect(entries.length).toBe(3);
    expect(entries[0].numericId).toBe(0);
    expect(entries[2].numericId).toBe(2);

    // skipRecent=0: all 8 should be prunable
    const allEntries = getPrunableEntries(state, [], 0);
    expect(allEntries.length).toBe(8);
  });

  test("tracks turns from user messages", () => {
    const state = createToolCacheState();
    const user = (text: string): AgentMessage =>
      ({ role: "user", content: [{ type: "text", text }], timestamp: Date.now() }) as any;

    const messages: AgentMessage[] = [
      user("first request"),
      assistant("t1", [{ id: "toolu_A", name: "read", args: { path: "a.txt" } }]),
      toolResult("toolu_A", "read", "aaa"),
      user("second request"),
      assistant("t2", [{ id: "toolu_B", name: "read", args: { path: "b.txt" } }]),
      toolResult("toolu_B", "read", "bbb"),
      user("third request"),
      assistant("t3", [{ id: "toolu_C", name: "read", args: { path: "c.txt" } }]),
      toolResult("toolu_C", "read", "ccc"),
    ];

    syncToolCache(state, messages);

    expect(state.currentTurn).toBe(3);
    expect(state.cache.get("toolu_A")!.turn).toBe(1);
    expect(state.cache.get("toolu_B")!.turn).toBe(2);
    expect(state.cache.get("toolu_C")!.turn).toBe(3);
  });

  test("turn protection excludes recent turns from prunable list", () => {
    const state = createToolCacheState();
    const user = (text: string): AgentMessage =>
      ({ role: "user", content: [{ type: "text", text }], timestamp: Date.now() }) as any;

    const messages: AgentMessage[] = [
      user("turn 1"),
      assistant("t1", [{ id: "toolu_A", name: "read", args: { path: "a.txt" } }]),
      toolResult("toolu_A", "read", "aaa"),
      user("turn 2"),
      assistant("t2", [{ id: "toolu_B", name: "read", args: { path: "b.txt" } }]),
      toolResult("toolu_B", "read", "bbb"),
      user("turn 3"),
      assistant("t3", [{ id: "toolu_C", name: "read", args: { path: "c.txt" } }]),
      toolResult("toolu_C", "read", "ccc"),
    ];

    syncToolCache(state, messages);

    // Protect last 2 turns, skipRecent=0 to isolate turn protection
    const entries = getPrunableEntries(state, [], 0, { enabled: true, turns: 2 });
    // Only turn 1 (toolu_A) should be prunable — turns 2+3 protected
    expect(entries.length).toBe(1);
    expect(entries[0].entry.paramKey).toBe("a.txt");

    // Without turn protection, all 3 are prunable
    const all = getPrunableEntries(state, [], 0);
    expect(all.length).toBe(3);
  });

  test("turn protection disabled passes through all entries", () => {
    const state = createToolCacheState();
    const user = (text: string): AgentMessage =>
      ({ role: "user", content: [{ type: "text", text }], timestamp: Date.now() }) as any;

    const messages: AgentMessage[] = [
      user("turn 1"),
      assistant("t1", [{ id: "toolu_A", name: "read", args: { path: "a.txt" } }]),
      toolResult("toolu_A", "read", "aaa"),
      user("turn 2"),
      assistant("t2", [{ id: "toolu_B", name: "read", args: { path: "b.txt" } }]),
      toolResult("toolu_B", "read", "bbb"),
    ];

    syncToolCache(state, messages);

    const entries = getPrunableEntries(state, [], 0, { enabled: false, turns: 2 });
    expect(entries.length).toBe(2);
  });
});

describe("extractParamKey", () => {
  test("extracts path for file operations", () => {
    expect(extractParamKey("read", { path: "src/index.ts" })).toBe("src/index.ts");
  });

  test("extracts command for bash", () => {
    expect(extractParamKey("bash", { command: "ls -la" })).toBe("ls -la");
  });

  test("truncates long commands", () => {
    const longCmd = "a".repeat(100);
    const key = extractParamKey("bash", { command: longCmd });
    expect(key.length).toBeLessThanOrEqual(60);
    expect(key.endsWith("...")).toBe(true);
  });

  test("falls back to tool name when no params", () => {
    expect(extractParamKey("unknown_tool", {})).toBe("unknown_tool");
  });
});
