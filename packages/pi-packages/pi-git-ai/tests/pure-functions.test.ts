/**
 * Unit tests for pi-git-ai pure exported functions.
 * Tests getEditedPaths and buildTranscript without needing a session.
 */

import { describe, expect, test } from "bun:test";
import { getEditedPaths, buildTranscript } from "../index";

// --- getEditedPaths ---

describe("getEditedPaths", () => {
  test("extracts path from edit tool", () => {
    const event = {
      toolName: "edit",
      toolCallId: "tc1",
      input: { path: "src/index.ts", oldText: "a", newText: "b" },
    } as any;
    expect(getEditedPaths(event)).toEqual(["src/index.ts"]);
  });

  test("extracts path from write tool", () => {
    const event = {
      toolName: "write",
      toolCallId: "tc2",
      input: { path: "README.md", content: "hello" },
    } as any;
    expect(getEditedPaths(event)).toEqual(["README.md"]);
  });

  test("extracts paths from apply_patch with multiple files", () => {
    const patch = `*** Begin Patch
*** Update File: src/a.ts
@@ -1,3 +1,3 @@
-old
+new
*** Add File: src/b.ts
@@ -0,0 +1 @@
+content
*** Delete File: src/c.ts
*** End Patch`;
    const event = {
      toolName: "apply_patch",
      toolCallId: "tc3",
      input: { patch },
    } as any;
    expect(getEditedPaths(event)).toEqual(["src/a.ts", "src/b.ts", "src/c.ts"]);
  });

  test("returns empty for non-file tools", () => {
    const event = {
      toolName: "bash",
      toolCallId: "tc4",
      input: { command: "ls" },
    } as any;
    expect(getEditedPaths(event)).toEqual([]);
  });

  test("returns empty for apply_patch with non-string patch", () => {
    const event = {
      toolName: "apply_patch",
      toolCallId: "tc5",
      input: { patch: 42 },
    } as any;
    expect(getEditedPaths(event)).toEqual([]);
  });

  test("handles apply_patch with no file markers", () => {
    const event = {
      toolName: "apply_patch",
      toolCallId: "tc6",
      input: { patch: "just some text" },
    } as any;
    expect(getEditedPaths(event)).toEqual([]);
  });
});

// --- buildTranscript ---

describe("buildTranscript", () => {
  test("extracts user text messages", () => {
    const entries = [{ type: "message", message: { role: "user", content: "fix the bug" } }];
    const result = buildTranscript(entries);
    expect(result).toEqual([{ type: "user", text: "fix the bug", timestamp: undefined }]);
  });

  test("extracts user content-array messages", () => {
    const entries = [
      {
        type: "message",
        message: {
          role: "user",
          content: [
            { type: "text", text: "first" },
            { type: "image", url: "img.png" },
            { type: "text", text: "second" },
          ],
        },
      },
    ];
    const result = buildTranscript(entries);
    expect(result).toEqual([{ type: "user", text: "first\nsecond", timestamp: undefined }]);
  });

  test("extracts assistant text, thinking, and tool_use", () => {
    const entries = [
      {
        type: "message",
        message: {
          role: "assistant",
          content: [
            { type: "thinking", thinking: "let me think" },
            { type: "text", text: "I will fix it" },
            { type: "toolCall", name: "edit", arguments: { path: "foo.ts" } },
          ],
        },
      },
    ];
    const result = buildTranscript(entries);
    expect(result).toHaveLength(3);
    expect(result[0]).toEqual({ type: "assistant", text: "I will fix it", timestamp: undefined });
    expect(result[1]).toEqual({ type: "thinking", text: "let me think", timestamp: undefined });
    expect(result[2]).toEqual({
      type: "tool_use",
      name: "edit",
      input: { path: "foo.ts" },
      timestamp: undefined,
    });
  });

  test("skips non-message entries", () => {
    const entries = [
      { type: "tool_result", message: { role: "tool", content: "ok" } },
      { type: "system", message: undefined },
      { type: "message", message: { role: "user", content: "hello" } },
    ];
    const result = buildTranscript(entries);
    expect(result).toHaveLength(1);
    expect(result[0].type).toBe("user");
  });

  test("preserves timestamps as ISO strings", () => {
    const ts = 1704067200000; // 2024-01-01T00:00:00Z
    const entries = [{ type: "message", message: { role: "user", content: "hi", timestamp: ts } }];
    const result = buildTranscript(entries);
    expect(result[0].timestamp).toBe("2024-01-01T00:00:00.000Z");
  });

  test("handles empty entries array", () => {
    expect(buildTranscript([])).toEqual([]);
  });

  test("skips empty user text", () => {
    const entries = [{ type: "message", message: { role: "user", content: "" } }];
    expect(buildTranscript(entries)).toEqual([]);
  });

  test("handles assistant content that is not an array", () => {
    const entries = [{ type: "message", message: { role: "assistant", content: "plain string" } }];
    // Should skip — assistant content must be array per spec
    expect(buildTranscript(entries)).toEqual([]);
  });

  test("tool_use defaults to empty input when no arguments", () => {
    const entries = [
      {
        type: "message",
        message: {
          role: "assistant",
          content: [{ type: "toolCall", name: "bash" }],
        },
      },
    ];
    const result = buildTranscript(entries);
    expect(result[0]).toEqual({
      type: "tool_use",
      name: "bash",
      input: {},
      timestamp: undefined,
    });
  });
});
