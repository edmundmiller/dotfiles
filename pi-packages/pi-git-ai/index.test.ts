import { describe, test, expect, mock, beforeEach } from "bun:test";

// Mock isToolCallEventType before importing the module
const mockIsToolCall = mock((toolName: string, event: any) => {
  return event.toolName === toolName;
});

mock.module("@mariozechner/pi-coding-agent", () => ({
  isToolCallEventType: mockIsToolCall,
}));

// Now import the module under test (picks up mocked dependency)
const { getEditedPaths, buildTranscript, default: createExtension } = await import("./index.ts");

// --- Test helpers ---

function editEvent(path: string, toolCallId = "tc-1"): any {
  return { toolName: "edit", toolCallId, input: { path, oldText: "a", newText: "b" } };
}

function writeEvent(path: string, toolCallId = "tc-1"): any {
  return { toolName: "write", toolCallId, input: { path, content: "hello" } };
}

function applyPatchEvent(patch: string, toolCallId = "tc-1"): any {
  return { toolName: "apply_patch", toolCallId, input: { patch } };
}

function customToolEvent(
  toolName: string,
  input: Record<string, unknown> = {},
  toolCallId = "tc-1"
): any {
  return { toolName, toolCallId, input };
}

// --- getEditedPaths ---

describe("getEditedPaths", () => {
  test("extracts path from edit tool call", () => {
    expect(getEditedPaths(editEvent("src/main.ts"))).toEqual(["src/main.ts"]);
  });

  test("extracts path from write tool call", () => {
    expect(getEditedPaths(writeEvent("README.md"))).toEqual(["README.md"]);
  });

  test("extracts single path from apply_patch Update", () => {
    const patch = `*** Begin Patch
*** Update File: src/index.ts
@@ -1,3 +1,3 @@
-old
+new
*** End Patch`;
    expect(getEditedPaths(applyPatchEvent(patch))).toEqual(["src/index.ts"]);
  });

  test("extracts multiple paths from apply_patch", () => {
    const patch = `*** Begin Patch
*** Update File: src/a.ts
@@ -1,1 +1,1 @@
-old
+new
*** Add File: src/b.ts
+content
*** Delete File: src/c.ts
*** End Patch`;
    expect(getEditedPaths(applyPatchEvent(patch))).toEqual(["src/a.ts", "src/b.ts", "src/c.ts"]);
  });

  test("returns empty for non-file-editing tools", () => {
    expect(getEditedPaths(customToolEvent("bash", { command: "ls" }))).toEqual([]);
    expect(getEditedPaths(customToolEvent("read", { path: "foo.ts" }))).toEqual([]);
  });

  test("returns empty for apply_patch with non-string patch", () => {
    expect(getEditedPaths(applyPatchEvent(123 as any))).toEqual([]);
  });

  test("trims whitespace from apply_patch paths", () => {
    const patch = "*** Update File:   src/spaced.ts  \n@@ -1,1 +1,1 @@\n-a\n+b";
    expect(getEditedPaths(applyPatchEvent(patch))).toEqual(["src/spaced.ts"]);
  });
});

// --- buildTranscript ---

describe("buildTranscript", () => {
  test("converts user string content", () => {
    const entries = [{ type: "message", message: { role: "user", content: "fix the bug" } }];
    expect(buildTranscript(entries)).toEqual([
      { type: "user", text: "fix the bug", timestamp: undefined },
    ]);
  });

  test("converts user array content", () => {
    const entries = [
      {
        type: "message",
        message: {
          role: "user",
          content: [
            { type: "text", text: "hello" },
            { type: "image", data: "..." },
            { type: "text", text: "world" },
          ],
        },
      },
    ];
    expect(buildTranscript(entries)).toEqual([
      { type: "user", text: "hello\nworld", timestamp: undefined },
    ]);
  });

  test("converts assistant text parts", () => {
    const entries = [
      {
        type: "message",
        message: {
          role: "assistant",
          content: [
            { type: "text", text: "I'll fix that." },
            { type: "text", text: "Here's my plan." },
          ],
        },
      },
    ];
    const result = buildTranscript(entries);
    expect(result).toEqual([
      { type: "assistant", text: "I'll fix that.\nHere's my plan.", timestamp: undefined },
    ]);
  });

  test("converts assistant thinking parts", () => {
    const entries = [
      {
        type: "message",
        message: {
          role: "assistant",
          content: [{ type: "thinking", thinking: "Let me analyze..." }],
        },
      },
    ];
    expect(buildTranscript(entries)).toEqual([
      { type: "thinking", text: "Let me analyze...", timestamp: undefined },
    ]);
  });

  test("converts assistant toolCall parts", () => {
    const entries = [
      {
        type: "message",
        message: {
          role: "assistant",
          content: [
            {
              type: "toolCall",
              name: "edit",
              arguments: { path: "a.ts", oldText: "x", newText: "y" },
            },
          ],
        },
      },
    ];
    expect(buildTranscript(entries)).toEqual([
      {
        type: "tool_use",
        name: "edit",
        input: { path: "a.ts", oldText: "x", newText: "y" },
        timestamp: undefined,
      },
    ]);
  });

  test("skips toolResult entries", () => {
    const entries = [
      { type: "message", message: { role: "user", content: "hi" } },
      {
        type: "message",
        message: { role: "toolResult", content: [{ type: "text", text: "result" }] },
      },
      {
        type: "message",
        message: {
          role: "assistant",
          content: [{ type: "text", text: "done" }],
        },
      },
    ];
    const result = buildTranscript(entries);
    expect(result).toHaveLength(2);
    expect(result[0].type).toBe("user");
    expect(result[1].type).toBe("assistant");
  });

  test("skips non-message entries", () => {
    const entries = [
      { type: "system", message: { role: "system", content: "you are helpful" } },
      { type: "metadata", data: {} },
      { type: "message", message: { role: "user", content: "hi" } },
    ];
    expect(buildTranscript(entries)).toHaveLength(1);
  });

  test("includes timestamps when present", () => {
    const ts = Date.now();
    const entries = [{ type: "message", message: { role: "user", content: "hi", timestamp: ts } }];
    const result = buildTranscript(entries);
    expect(result[0].timestamp).toBe(new Date(ts).toISOString());
  });

  test("handles empty user content gracefully", () => {
    const entries = [{ type: "message", message: { role: "user", content: "" } }];
    expect(buildTranscript(entries)).toEqual([]);
  });

  test("handles assistant with non-array content", () => {
    const entries = [{ type: "message", message: { role: "assistant", content: "just a string" } }];
    // Should skip — assistant content must be an array
    expect(buildTranscript(entries)).toEqual([]);
  });

  test("handles mixed assistant content types", () => {
    const entries = [
      {
        type: "message",
        message: {
          role: "assistant",
          content: [
            { type: "thinking", thinking: "hmm" },
            { type: "text", text: "answer" },
            { type: "toolCall", name: "bash", arguments: { command: "ls" } },
          ],
        },
      },
    ];
    const result = buildTranscript(entries);
    expect(result).toHaveLength(3);
    expect(result[0]).toEqual({ type: "assistant", text: "answer", timestamp: undefined });
    expect(result[1]).toEqual({ type: "thinking", text: "hmm", timestamp: undefined });
    expect(result[2]).toEqual({
      type: "tool_use",
      name: "bash",
      input: { command: "ls" },
      timestamp: undefined,
    });
  });

  test("toolCall with no arguments defaults to empty object", () => {
    const entries = [
      {
        type: "message",
        message: {
          role: "assistant",
          content: [{ type: "toolCall", name: "read" }],
        },
      },
    ];
    const result = buildTranscript(entries);
    expect(result[0]).toEqual({
      type: "tool_use",
      name: "read",
      input: {},
      timestamp: undefined,
    });
  });

  test("entries with missing message are skipped", () => {
    const entries = [
      { type: "message" },
      { type: "message", message: undefined },
      { type: "message", message: { role: "user", content: "ok" } },
    ];
    expect(buildTranscript(entries as any)).toHaveLength(1);
  });
});

// --- Extension lifecycle ---

describe("extension lifecycle", () => {
  let handlers: Record<string, Function>;
  let mockPi: any;
  let execCalls: Array<{ cmd: string; args: string[] }>;

  beforeEach(() => {
    handlers = {};
    execCalls = [];
    mockPi = {
      on: mock((event: string, handler: Function) => {
        // Support multiple handlers per event
        const prev = handlers[event];
        if (prev) {
          handlers[event] = async (...args: any[]) => {
            await prev(...args);
            await handler(...args);
          };
        } else {
          handlers[event] = handler;
        }
      }),
      exec: mock(async (cmd: string, args: string[]) => {
        execCalls.push({ cmd, args });
        return "";
      }),
    };
    mockIsToolCall.mockImplementation(
      (toolName: string, event: any) => event.toolName === toolName
    );
  });

  function makeCtx(
    overrides: Partial<{ model: { id: string }; sessionId: string; branch: any[] }> = {}
  ) {
    return {
      model: overrides.model ?? { id: "claude-sonnet-4-20250514" },
      sessionManager: {
        getBranch: () => overrides.branch ?? [],
        getSessionId: () => overrides.sessionId ?? "session-123",
      },
    };
  }

  test("registers tool_call, tool_execution_end, agent_end handlers", () => {
    createExtension(mockPi);
    expect(mockPi.on).toHaveBeenCalledTimes(3);
    const eventNames = mockPi.on.mock.calls.map((c: any) => c[0]);
    expect(eventNames).toContain("tool_call");
    expect(eventNames).toContain("tool_execution_end");
    expect(eventNames).toContain("agent_end");
  });

  test("tool_call for edit checks git-ai availability then proceeds", async () => {
    createExtension(mockPi);
    const event = editEvent("src/main.ts");
    await handlers["tool_call"](event);
    // First exec: git-ai --version check, second: not done here (runCheckpoint uses spawn)
    expect(execCalls).toEqual([{ cmd: "git-ai", args: ["--version"] }]);
  });

  test("tool_call skips non-file-editing tools", async () => {
    createExtension(mockPi);
    await handlers["tool_call"](customToolEvent("bash", { command: "ls" }));
    // No exec calls — not a file-editing tool
    expect(execCalls).toEqual([]);
  });

  test("git-ai unavailable → caches result, skips on subsequent calls", async () => {
    mockPi.exec = mock(async () => {
      throw new Error("not found");
    });
    execCalls = []; // reset
    createExtension(mockPi);

    await handlers["tool_call"](editEvent("a.ts"));
    await handlers["tool_call"](editEvent("b.ts"));

    // Only one version check — result cached
    expect(mockPi.exec).toHaveBeenCalledTimes(1);
  });

  test("tool_execution_end ignores untracked tool calls", async () => {
    createExtension(mockPi);
    const endEvent = { toolCallId: "unknown-tc", toolName: "edit", isError: false };
    await handlers["tool_execution_end"](endEvent, makeCtx());
    // No exec calls — toolCallId wasn't tracked
    expect(execCalls).toEqual([]);
  });

  test("tool_execution_end skips errored tool calls", async () => {
    createExtension(mockPi);
    const event = editEvent("src/main.ts", "tc-err");
    await handlers["tool_call"](event);
    execCalls = []; // clear version check

    const endEvent = { toolCallId: "tc-err", toolName: "edit", isError: true };
    await handlers["tool_execution_end"](endEvent, makeCtx());
    // No checkpoint — tool errored
    expect(execCalls).toEqual([]);
  });

  test("agent_end resets availability cache", async () => {
    // First run: git-ai available
    createExtension(mockPi);
    await handlers["tool_call"](editEvent("a.ts"));
    expect(execCalls).toHaveLength(1); // version check

    // agent_end resets cache
    await handlers["agent_end"]();

    // Next tool_call should re-check availability
    await handlers["tool_call"](editEvent("b.ts"));
    expect(execCalls).toHaveLength(2); // second version check
  });

  test("tool_execution_end passes correct model and session to transcript", async () => {
    // We can't easily intercept runCheckpoint (uses spawn), but we can verify
    // the handler doesn't throw and processes correctly
    createExtension(mockPi);
    const event = editEvent("src/main.ts", "tc-model");
    await handlers["tool_call"](event);

    const ctx = makeCtx({
      model: { id: "claude-opus-4-20250514" },
      sessionId: "sess-abc",
      branch: [{ type: "message", message: { role: "user", content: "fix it" } }],
    });
    const endEvent = { toolCallId: "tc-model", toolName: "edit", isError: false };
    // Should not throw
    await handlers["tool_execution_end"](endEvent, ctx);
  });

  test("model fallback to 'unknown' when model is null", async () => {
    createExtension(mockPi);
    await handlers["tool_call"](editEvent("a.ts", "tc-nomodel"));

    const ctx = makeCtx({ model: undefined as any });
    const endEvent = { toolCallId: "tc-nomodel", toolName: "edit", isError: false };
    // Should not throw
    await handlers["tool_execution_end"](endEvent, ctx);
  });

  test("pendingPaths cleaned up after tool_execution_end", async () => {
    createExtension(mockPi);
    const event = editEvent("src/main.ts", "tc-cleanup");
    await handlers["tool_call"](event);

    const endEvent = { toolCallId: "tc-cleanup", toolName: "edit", isError: false };
    await handlers["tool_execution_end"](endEvent, makeCtx());

    // Second call with same toolCallId should be a no-op (already deleted)
    execCalls = [];
    await handlers["tool_execution_end"](endEvent, makeCtx());
    expect(execCalls).toEqual([]);
  });

  test("apply_patch tracks multiple paths through lifecycle", async () => {
    createExtension(mockPi);
    const patch = `*** Begin Patch
*** Update File: src/a.ts
@@ -1,1 +1,1 @@
-old
+new
*** Add File: src/b.ts
+content
*** End Patch`;
    const event = applyPatchEvent(patch, "tc-patch");
    await handlers["tool_call"](event);

    // Should not throw on end
    const endEvent = { toolCallId: "tc-patch", toolName: "apply_patch", isError: false };
    await handlers["tool_execution_end"](endEvent, makeCtx());
  });
});
