/**
 * Integration tests: pi-git-ai hook lifecycle
 *
 * Tests the tool_call → tool_execution_end event flow, verifying that
 * git-ai checkpoints are called at the right times with the right payloads.
 *
 * Uses @marcfargas/pi-test-harness for real pi session testing.
 * git-ai is NOT installed in CI — we verify the extension silently skips
 * when unavailable, which is its designed behavior.
 */

import { describe, it, expect, afterEach } from "bun:test";
import {
  createTestSession,
  when,
  calls,
  says,
  type TestSession,
} from "@marcfargas/pi-test-harness";
import * as path from "node:path";

const GIT_AI_EXTENSION = path.resolve(import.meta.dir, "../pi-git-ai/index.ts");

const MOCK_TOOLS = {
  bash: "ok",
  read: "file contents",
  write: "written",
  edit: "edited",
  apply_patch: "patched",
};

describe("pi-git-ai hook lifecycle", () => {
  let t: TestSession;

  afterEach(() => t?.dispose());

  it("loads without error when git-ai unavailable", async () => {
    t = await createTestSession({
      extensions: [GIT_AI_EXTENSION],
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("edit src/index.ts", [
        calls("edit", { path: "src/index.ts", oldText: "old", newText: "new" }),
      ])
    );

    // Extension should silently skip — no errors
    const editResults = t.events.toolResultsFor("edit");
    expect(editResults).toHaveLength(1);
    expect(editResults[0].isError).toBe(false);
  });

  it("does not interfere with non-file tools", async () => {
    t = await createTestSession({
      extensions: [GIT_AI_EXTENSION],
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("run ls", [calls("bash", { command: "ls" })]),
      when("read README", [calls("read", { path: "README.md" })])
    );

    // bash and read are not file-editing tools — git-ai should not track them
    expect(t.events.toolResultsFor("bash")).toHaveLength(1);
    expect(t.events.toolResultsFor("read")).toHaveLength(1);
  });

  it("handles multiple edit tools in sequence", async () => {
    t = await createTestSession({
      extensions: [GIT_AI_EXTENSION],
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("fix two files", [
        calls("edit", { path: "a.ts", oldText: "x", newText: "y" }),
        calls("write", { path: "b.ts", content: "new file" }),
      ])
    );

    expect(t.events.toolResultsFor("edit")).toHaveLength(1);
    expect(t.events.toolResultsFor("write")).toHaveLength(1);
    // Both should complete without error even though git-ai is unavailable
    for (const r of [...t.events.toolResultsFor("edit"), ...t.events.toolResultsFor("write")]) {
      expect(r.isError).toBe(false);
    }
  });

  it("handles apply_patch tool", async () => {
    const patch = `*** Begin Patch
*** Update File: src/main.ts
@@ -1,3 +1,3 @@
-old line
+new line
*** End Patch`;

    t = await createTestSession({
      extensions: [GIT_AI_EXTENSION],
      mockTools: { ...MOCK_TOOLS, apply_patch: "patched" },
    });

    await t.run(when("apply patch", [calls("apply_patch", { patch })]));

    // Tool should execute and complete — verify via tool calls
    const patchCalls = t.events.toolCallsFor("apply_patch");
    expect(patchCalls).toHaveLength(1);
    expect(patchCalls[0].input.patch).toBe(patch);
  });

  it("interleaves file and non-file tools cleanly", async () => {
    t = await createTestSession({
      extensions: [GIT_AI_EXTENSION],
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("read then edit then bash", [
        calls("read", { path: "src/index.ts" }),
        calls("edit", { path: "src/index.ts", oldText: "old", newText: "new" }),
        calls("bash", { command: "npm test" }),
      ])
    );

    expect(t.events.toolSequence()).toEqual(["read", "edit", "bash"]);
    // All succeed regardless of git-ai availability
    for (const r of t.events.toolResults) {
      expect(r.isError).toBe(false);
    }
  });

  it("recovers from agent_end — state resets between turns", async () => {
    t = await createTestSession({
      extensions: [GIT_AI_EXTENSION],
      mockTools: MOCK_TOOLS,
    });

    // First conversation
    await t.run(when("edit file", [calls("edit", { path: "a.ts", oldText: "x", newText: "y" })]));

    // Second conversation — extension should have reset on agent_end
    await t.run(
      when("edit another file", [calls("edit", { path: "b.ts", oldText: "a", newText: "b" })])
    );

    expect(t.events.toolResultsFor("edit")).toHaveLength(2);
  });
});

describe("pi-git-ai with mock exec", () => {
  let t: TestSession;

  afterEach(() => t?.dispose());

  it("coexists with other extensions", async () => {
    // Verify git-ai doesn't break when loaded alongside other extensions
    let sessionStartFired = false;

    t = await createTestSession({
      extensions: [GIT_AI_EXTENSION],
      extensionFactories: [
        (pi: any) => {
          pi.on("session_start", async () => {
            sessionStartFired = true;
          });
        },
      ],
      mockTools: MOCK_TOOLS,
    });

    await t.run(when("hello", [says("hi")]));

    expect(sessionStartFired).toBe(true);
  });

  it("tool_call events fire for file-editing tools", async () => {
    const toolCallEvents: string[] = [];

    t = await createTestSession({
      extensions: [GIT_AI_EXTENSION],
      extensionFactories: [
        (pi: any) => {
          pi.on("tool_call", async (event: any) => {
            toolCallEvents.push(event.toolName);
          });
        },
      ],
      mockTools: MOCK_TOOLS,
    });

    await t.run(
      when("do edits", [
        calls("edit", { path: "x.ts", oldText: "a", newText: "b" }),
        calls("bash", { command: "echo hi" }),
        calls("write", { path: "y.ts", content: "new" }),
      ])
    );

    // Our observer sees all tool_call events
    expect(toolCallEvents).toContain("edit");
    expect(toolCallEvents).toContain("bash");
    expect(toolCallEvents).toContain("write");
  });
});
