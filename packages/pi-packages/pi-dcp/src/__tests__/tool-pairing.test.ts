/**
 * Tests for tool pairing integrity in the pruning pipeline.
 *
 * Spec tests: document intended behavior of hash + dedup + tool-pairing
 * Regression tests: reproduce the bugs that caused API 400 errors
 */

import { describe, test, expect, beforeAll } from "bun:test";
import type { AgentMessage } from "@mariozechner/pi-agent-core";
import { hashMessage, isSameOperation } from "../metadata";
import { applyPruningWorkflow } from "../workflow";
import { registerRule } from "../registry";
import { deduplicationRule } from "../rules/deduplication";
import { recencyRule } from "../rules/recency";
import { toolPairingRule } from "../rules/tool-pairing";
import { repairOrphanedToolPairsPostPruning } from "../events/context";
import { getLogger } from "../logger";
import type { DcpConfigWithPruneRuleObjects } from "../types";

// --- Helpers ---

function makeAssistant(
  toolCalls: { id: string; name: string; args?: Record<string, any> }[],
  text = "\n\n"
): AgentMessage {
  return {
    role: "assistant",
    content: [
      { type: "text", text },
      ...toolCalls.map((tc) => ({
        type: "toolCall" as const,
        id: tc.id,
        name: tc.name,
        arguments: tc.args ?? {},
      })),
    ],
    api: "anthropic-messages",
    provider: "anthropic",
    model: "claude-sonnet-4-20250514",
    usage: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, totalTokens: 0, cost: {} },
    stopReason: "toolUse",
    timestamp: Date.now(),
  } as any;
}

function makeToolResult(toolCallId: string, toolName: string, content: string): AgentMessage {
  return {
    role: "toolResult",
    toolCallId,
    toolName,
    content: [{ type: "text", text: content }],
    isError: false,
    timestamp: Date.now(),
  } as any;
}

function makeUser(text: string): AgentMessage {
  return {
    role: "user",
    content: text,
    timestamp: Date.now(),
  } as any;
}

function makeConfig(
  rules: DcpConfigWithPruneRuleObjects["rules"],
  keepRecentCount = 4
): DcpConfigWithPruneRuleObjects {
  return {
    enabled: true,
    debug: false,
    keepRecentCount,
    rules,
  };
}

/** Extract all toolCallIds from toolResult messages in a list */
function getToolResultIds(messages: AgentMessage[]): string[] {
  return messages.filter((m) => m.role === "toolResult").map((m) => (m as any).toolCallId);
}

/** Extract all toolCall IDs from assistant messages */
function getToolUseIds(messages: AgentMessage[]): string[] {
  return messages
    .filter((m) => m.role === "assistant" && Array.isArray(m.content))
    .flatMap((m) =>
      ((m as any).content as any[]).filter((b) => b?.type === "toolCall").map((b) => b.id)
    );
}

/** Verify every tool_result has a matching tool_use AND vice versa (API compliance) */
function assertToolPairsIntact(messages: AgentMessage[]) {
  const toolUseIds = new Set(getToolUseIds(messages));
  const toolResultIds = new Set(getToolResultIds(messages));

  // Every tool_result must reference an existing tool_use
  for (const id of toolResultIds) {
    expect(toolUseIds.has(id)).toBe(true);
  }

  // Every tool_use must have a corresponding tool_result
  for (const id of toolUseIds) {
    expect(toolResultIds.has(id)).toBe(true);
  }
}

// --- Register rules ---

beforeAll(() => {
  registerRule(deduplicationRule);
  registerRule(recencyRule);
  registerRule(toolPairingRule);
});

// ============================================================
// Spec tests: hashMessage
// ============================================================

describe("hashMessage", () => {
  test("different toolCall arguments produce different hashes", () => {
    const msg1 = makeAssistant([{ id: "a", name: "bash", args: { command: "ls" } }]);
    const msg2 = makeAssistant([{ id: "b", name: "bash", args: { command: "pwd" } }]);
    expect(hashMessage(msg1)).not.toBe(hashMessage(msg2));
  });

  test("different toolCall IDs produce different hashes", () => {
    const msg1 = makeAssistant([{ id: "toolu_abc", name: "bash", args: { command: "ls" } }]);
    const msg2 = makeAssistant([{ id: "toolu_xyz", name: "bash", args: { command: "ls" } }]);
    expect(hashMessage(msg1)).not.toBe(hashMessage(msg2));
  });

  test("toolResult messages with different toolCallIds produce different hashes", () => {
    const tr1 = makeToolResult("toolu_abc", "bash", "same output");
    const tr2 = makeToolResult("toolu_xyz", "bash", "same output");
    expect(hashMessage(tr1)).not.toBe(hashMessage(tr2));
  });

  test("identical messages produce the same hash", () => {
    const msg1 = makeUser("hello");
    const msg2 = makeUser("hello");
    expect(hashMessage(msg1)).toBe(hashMessage(msg2));
  });
});

// ============================================================
// Regression: hashMessage ignored toolCall blocks (type mismatch)
// ============================================================

describe("regression: toolCall type mismatch in hashMessage", () => {
  test("assistant messages with different tool calls must NOT hash identically", () => {
    // REGRESSION: hashMessage checked for type:"tool_use" but pi uses type:"toolCall"
    // All assistant messages hashed to just their text ("\n\n"), causing false dedup
    const msg1 = makeAssistant([
      { id: "toolu_abc", name: "bash", args: { command: "find / -name foo" } },
    ]);
    const msg2 = makeAssistant([
      { id: "toolu_xyz", name: "bash", args: { command: "cat /etc/passwd" } },
    ]);

    // Before fix: both hashed to hash("\n\n") → same hash
    // After fix: toolCall blocks included → different hashes
    expect(hashMessage(msg1)).not.toBe(hashMessage(msg2));
  });
});

// ============================================================
// Regression: false dedup cascading to tool pair destruction
// ============================================================

describe("regression: false dedup cascade destroys tool pairs", () => {
  test("dedup must not prune assistant messages with tool calls", () => {
    // REGRESSION: dedup treated all assistant+toolCall messages as duplicates
    // because hashMessage returned identical hashes. Tool-pairing then cascaded
    // the prune to their tool_results → massive context loss.
    const messages: AgentMessage[] = [
      makeUser("do stuff"),
      makeAssistant([{ id: "a1", name: "bash", args: { command: "find /" } }]),
      makeToolResult("a1", "bash", "file1.txt\nfile2.txt"),
      makeAssistant([{ id: "b1", name: "bash", args: { command: "cat file1.txt" } }]),
      makeToolResult("b1", "bash", "contents of file1"),
      makeAssistant([{ id: "c1", name: "bash", args: { command: "cat file2.txt" } }]),
      makeToolResult("c1", "bash", "contents of file2"),
    ];

    const config = makeConfig(
      [deduplicationRule, toolPairingRule, recencyRule],
      2 // only protect last 2 messages
    );

    const result = applyPruningWorkflow(messages, config);

    // All 3 assistant+toolResult pairs must survive (they're not duplicates)
    expect(getToolUseIds(result)).toContain("a1");
    expect(getToolUseIds(result)).toContain("b1");
    expect(getToolUseIds(result)).toContain("c1");
    assertToolPairsIntact(result);
  });

  test("dedup still prunes genuinely duplicate non-tool messages", () => {
    const messages: AgentMessage[] = [
      makeUser("hello"),
      {
        role: "assistant",
        content: [{ type: "text", text: "Hi there!" }],
        timestamp: Date.now(),
      } as any,
      makeUser("do something"),
      makeAssistant([{ id: "a1", name: "bash", args: { command: "ls" } }]),
      makeToolResult("a1", "bash", "output"),
      // Exact duplicate text response (no tool calls)
      {
        role: "assistant",
        content: [{ type: "text", text: "Hi there!" }],
        timestamp: Date.now(),
      } as any,
    ];

    const config = makeConfig([deduplicationRule, toolPairingRule, recencyRule], 2);
    const result = applyPruningWorkflow(messages, config);

    // The duplicate text-only assistant should be pruned
    const textOnlyAssistants = result.filter(
      (m) =>
        m.role === "assistant" &&
        Array.isArray(m.content) &&
        (m.content as any[]).every((b: any) => b.type !== "toolCall")
    );
    // One should be pruned, but at least the tool pair survives
    assertToolPairsIntact(result);
  });
});

// ============================================================
// Spec: tool-pairing rule preserves pairs across recency boundary
// ============================================================

describe("tool-pairing across recency boundary", () => {
  test("recency un-pruning a tool_result also keeps its tool_use", () => {
    // Scenario: keepRecentCount boundary splits a tool pair.
    // Recency protects the tool_result but not its tool_use (assistant).
    // Tool-pairing repair must resurrect the assistant.
    const messages: AgentMessage[] = [
      makeUser("start"),
      makeAssistant([{ id: "old1", name: "bash", args: { command: "echo old" } }]),
      makeToolResult("old1", "bash", "old"),
      makeUser("middle"),
      makeAssistant([{ id: "boundary1", name: "bash", args: { command: "echo boundary" } }]),
      makeToolResult("boundary1", "bash", "boundary"), // ← recency protects this
      makeUser("recent"),
      makeAssistant([{ id: "new1", name: "bash", args: { command: "echo new" } }]),
      makeToolResult("new1", "bash", "new"),
    ];

    // keepRecentCount=4 protects indices 5-8 (toolResult:boundary, user, assistant, toolResult)
    // but NOT index 4 (assistant:boundary1). Repair must catch this.
    const config = makeConfig([deduplicationRule, toolPairingRule, recencyRule], 4);

    const result = applyPruningWorkflow(messages, config);
    assertToolPairsIntact(result);

    // The boundary pair must both be present
    expect(getToolUseIds(result)).toContain("boundary1");
    expect(getToolResultIds(result)).toContain("boundary1");
  });

  test("all tool pairs intact after full pipeline with aggressive recency", () => {
    // 10 tool call rounds, keepRecentCount=3
    const messages: AgentMessage[] = [makeUser("go")];
    for (let i = 0; i < 10; i++) {
      messages.push(
        makeAssistant([{ id: `t${i}`, name: "bash", args: { command: `cmd${i}` } }]),
        makeToolResult(`t${i}`, "bash", `output${i}`)
      );
    }

    const config = makeConfig([deduplicationRule, toolPairingRule, recencyRule], 3);

    const result = applyPruningWorkflow(messages, config);
    assertToolPairsIntact(result);
  });
});

// ============================================================
// Spec: repairOrphanedToolPairsPostPruning (layer 2 safety net)
// ============================================================

describe("repairOrphanedToolPairsPostPruning", () => {
  const logger = getLogger();

  test("removes orphaned tool_result when its assistant was removed", () => {
    // Simulates layer 2 removing an assistant's toolCall blocks entirely
    const messages: AgentMessage[] = [
      makeUser("start"),
      // Assistant with toolCall:A was removed by LLM-driven pruning — only text remains
      {
        role: "assistant",
        content: [{ type: "text", text: "Let me check." }],
        timestamp: Date.now(),
      } as any,
      // But the tool_result for A survived
      makeToolResult("orphan_a", "bash", "some output"),
      makeUser("next"),
      makeAssistant([{ id: "kept_b", name: "bash", args: { command: "ls" } }]),
      makeToolResult("kept_b", "bash", "file.txt"),
    ];

    const result = repairOrphanedToolPairsPostPruning(messages, logger);

    // orphan_a should be removed
    expect(getToolResultIds(result)).not.toContain("orphan_a");
    // kept_b pair should remain
    expect(getToolResultIds(result)).toContain("kept_b");
    expect(getToolUseIds(result)).toContain("kept_b");
  });

  test("removes orphaned toolCall blocks from assistant when tool_result is gone", () => {
    const messages: AgentMessage[] = [
      makeUser("start"),
      // Assistant has toolCall A and B, but only B's result exists
      makeAssistant([
        { id: "orphan_a", name: "write", args: { path: "foo.ts" } },
        { id: "kept_b", name: "bash", args: { command: "ls" } },
      ]),
      // Only B's result — A's was removed by LLM-driven pruning
      makeToolResult("kept_b", "bash", "file.txt"),
    ];

    const result = repairOrphanedToolPairsPostPruning(messages, logger);

    // orphan_a toolCall should be stripped from the assistant
    expect(getToolUseIds(result)).not.toContain("orphan_a");
    // kept_b pair intact
    expect(getToolUseIds(result)).toContain("kept_b");
    expect(getToolResultIds(result)).toContain("kept_b");
  });

  test("removes assistant entirely when all its content is orphaned toolCalls", () => {
    // Assistant with ONLY toolCall blocks (no text) — should be removed entirely
    const messages: AgentMessage[] = [
      makeUser("start"),
      {
        role: "assistant",
        content: [
          { type: "toolCall", id: "orphan_a", name: "write", arguments: { path: "foo.ts" } },
        ],
        timestamp: Date.now(),
      } as any,
      // No tool_result for orphan_a
      makeUser("next"),
    ];

    const result = repairOrphanedToolPairsPostPruning(messages, logger);

    // The assistant should be removed entirely (no content left)
    expect(result.filter((m) => m.role === "assistant")).toHaveLength(0);
    expect(getToolUseIds(result)).not.toContain("orphan_a");
  });

  test("keeps assistant text when only its toolCalls are orphaned", () => {
    // Assistant has text + orphaned toolCall — text survives, toolCall stripped
    const messages: AgentMessage[] = [
      makeUser("start"),
      makeAssistant([{ id: "orphan_a", name: "write", args: { path: "foo.ts" } }]),
      // No tool_result for orphan_a
      makeUser("next"),
    ];

    const result = repairOrphanedToolPairsPostPruning(messages, logger);

    // Assistant kept (has text) but toolCall stripped
    expect(result.filter((m) => m.role === "assistant")).toHaveLength(1);
    expect(getToolUseIds(result)).not.toContain("orphan_a");
  });

  test("passes through valid messages untouched", () => {
    const messages: AgentMessage[] = [
      makeUser("hello"),
      makeAssistant([{ id: "a", name: "bash", args: { command: "echo hi" } }]),
      makeToolResult("a", "bash", "hi"),
    ];

    const result = repairOrphanedToolPairsPostPruning(messages, logger);
    expect(result).toHaveLength(3);
    assertToolPairsIntact(result);
  });
});

// ============================================================
// Regression: isSameOperation broken by hashMessage change
// ============================================================

describe("regression: isSameOperation with unique toolCallIds", () => {
  test("same bash command with different toolCallIds matches as same operation", () => {
    // REGRESSION: hashMessage now includes toolCallId for dedup correctness,
    // but isSameOperation used hashMessage to compare operations. Two retries
    // of the same command would never match, breaking error-purging.
    const err = makeToolResult("toolu_first", "bash", "Error: command failed");
    const success = makeToolResult("toolu_retry", "bash", "Error: command failed");
    // Same content = same operation (used for error resolution tracking)
    expect(isSameOperation(err, success)).toBe(true);
  });

  test("different bash outputs are not the same operation", () => {
    const tr1 = makeToolResult("toolu_a", "bash", "output A");
    const tr2 = makeToolResult("toolu_b", "bash", "output B");
    expect(isSameOperation(tr1, tr2)).toBe(false);
  });

  test("different tool names are not the same operation", () => {
    const tr1 = makeToolResult("toolu_a", "bash", "same output");
    const tr2 = makeToolResult("toolu_b", "read", "same output");
    expect(isSameOperation(tr1, tr2)).toBe(false);
  });
});
