/**
 * Tests for LLM-callable DCP tools (prune, distill, compress)
 */

import { describe, test, expect } from "bun:test";
import { createToolCacheState, syncToolCache, type ToolCacheState } from "../src/tool-cache";
import { executePrune } from "../src/tools/prune";
import { executeDistill } from "../src/tools/distill";
import { executeCompress, type CompressSummary } from "../src/tools/compress";
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

function toolResult(callId: string, toolName: string, text: string): ToolResultMessage {
  return {
    role: "toolResult",
    toolCallId: callId,
    toolName,
    content: [{ type: "text", text }],
    isError: false,
    timestamp: Date.now(),
  };
}

function setupState(): ToolCacheState {
  const state = createToolCacheState();
  const messages: AgentMessage[] = [
    assistant("read a", [{ id: "toolu_0", name: "read", args: { path: "a.txt" } }]),
    toolResult("toolu_0", "read", "aaaa"),
    assistant("read b", [{ id: "toolu_1", name: "read", args: { path: "b.txt" } }]),
    toolResult("toolu_1", "read", "bbbb"),
    assistant("write c", [{ id: "toolu_2", name: "write", args: { path: "c.txt" } }]),
    toolResult("toolu_2", "write", "done"),
    assistant("bash", [{ id: "toolu_3", name: "bash", args: { command: "ls" } }]),
    toolResult("toolu_3", "bash", "a.txt\nb.txt\nc.txt"),
  ];
  syncToolCache(state, messages);
  return state;
}

describe("dcp_prune", () => {
  test("prunes by numeric ID", () => {
    const state = setupState();
    const result = executePrune(state, { ids: ["0", "2"] });

    expect(result.pruned).toBe(2);
    expect(state.prunedIds.has("toolu_0")).toBe(true);
    expect(state.prunedIds.has("toolu_2")).toBe(true);
    expect(state.prunedIds.has("toolu_1")).toBe(false);
  });

  test("skips invalid IDs", () => {
    const state = setupState();
    const result = executePrune(state, { ids: ["99", "abc"] });

    expect(result.pruned).toBe(0);
    expect(result.skipped.length).toBe(2);
  });

  test("skips already pruned", () => {
    const state = setupState();
    executePrune(state, { ids: ["0"] });
    const result = executePrune(state, { ids: ["0"] });

    expect(result.pruned).toBe(0);
    expect(result.skipped[0]).toContain("already pruned");
  });

  test("respects protected tools", () => {
    const state = setupState();
    const result = executePrune(state, { ids: ["0"] }, ["read"]);

    expect(result.pruned).toBe(0);
    expect(result.skipped[0]).toContain("protected");
  });
});

describe("dcp_distill", () => {
  test("distills with summary text", () => {
    const state = setupState();
    const result = executeDistill(state, {
      targets: [{ id: "0", distillation: "File a.txt contains configuration data" }],
    });

    expect(result.distilled).toBe(1);
    expect(state.prunedIds.has("toolu_0")).toBe(true);
    expect(state.distillations.get("toolu_0")).toBe("File a.txt contains configuration data");
  });

  test("skips protected tools", () => {
    const state = setupState();
    const result = executeDistill(state, { targets: [{ id: "0", distillation: "summary" }] }, [
      "read",
    ]);

    expect(result.distilled).toBe(0);
  });
});

describe("dcp_compress", () => {
  test("compresses a range of tool calls", () => {
    const state = setupState();
    const summaries: CompressSummary[] = [];

    const result = executeCompress(state, summaries, {
      topic: "initial file reads",
      startId: "0",
      endId: "1",
      summary: "Read a.txt and b.txt, both contain config data",
    });

    expect("compressed" in result && result.compressed).toBe(2);
    expect(summaries.length).toBe(1);
    expect(summaries[0].compressedIds).toContain("toolu_0");
    expect(summaries[0].compressedIds).toContain("toolu_1");
    expect(state.prunedIds.has("toolu_0")).toBe(true);
    expect(state.prunedIds.has("toolu_1")).toBe(true);
  });

  test("rejects invalid range", () => {
    const state = setupState();
    const summaries: CompressSummary[] = [];

    const result = executeCompress(state, summaries, {
      topic: "test",
      startId: "3",
      endId: "1",
      summary: "backwards",
    });

    expect("error" in result).toBe(true);
  });

  test("skips already pruned in range", () => {
    const state = setupState();
    state.prunedIds.add("toolu_0");
    const summaries: CompressSummary[] = [];

    const result = executeCompress(state, summaries, {
      topic: "reads",
      startId: "0",
      endId: "1",
      summary: "summary",
    });

    expect("compressed" in result && result.compressed).toBe(1);
  });
});
