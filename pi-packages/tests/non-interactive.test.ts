/**
 * Integration tests: pi-non-interactive
 *
 * Verifies the extension registers a bash tool replacement that injects
 * non-interactive env vars (GIT_EDITOR, PAGER, etc.) and blocks interactive
 * command patterns that cause hung tool runs.
 *
 * Uses @marcfargas/pi-test-harness.
 */

import { describe, it, expect, afterEach } from "bun:test";
import { createTestSession, when, calls, type TestSession } from "@marcfargas/pi-test-harness";
import * as path from "node:path";

const EXTENSION = path.resolve(import.meta.dir, "../pi-non-interactive/index.ts");

describe("pi-non-interactive", () => {
  let t: TestSession;

  afterEach(() => t?.dispose());

  it("registers a bash tool", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
    });

    await t.run(when("run echo", [calls("bash", { command: "echo hello" })]));

    const results = t.events.toolResultsFor("bash");
    expect(results).toHaveLength(1);
    expect(results[0].isError).toBe(false);
    expect(results[0].text).toContain("hello");
  });

  it("injects GIT_EDITOR=true to prevent editor hangs", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
    });

    await t.run(when("check env", [calls("bash", { command: "echo $GIT_EDITOR" })]));

    const results = t.events.toolResultsFor("bash");
    expect(results[0].text).toContain("true");
  });

  it("injects GIT_PAGER=cat to prevent pager hangs", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
    });

    await t.run(when("check pager", [calls("bash", { command: "echo $GIT_PAGER" })]));

    const results = t.events.toolResultsFor("bash");
    expect(results[0].text).toContain("cat");
  });

  it("injects PAGER=cat", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
    });

    await t.run(when("check pager", [calls("bash", { command: "echo $PAGER" })]));

    const results = t.events.toolResultsFor("bash");
    expect(results[0].text).toContain("cat");
  });

  it("injects BAT_PAGER=cat", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
    });

    await t.run(when("check bat", [calls("bash", { command: "echo $BAT_PAGER" })]));

    const results = t.events.toolResultsFor("bash");
    expect(results[0].text).toContain("cat");
  });

  it("injects LESS=-FX", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
    });

    await t.run(when("check less", [calls("bash", { command: "echo $LESS" })]));

    const results = t.events.toolResultsFor("bash");
    expect(results[0].text).toContain("-FX");
  });

  it("injects GIT_SEQUENCE_EDITOR=true", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
    });

    await t.run(
      when("check seq editor", [calls("bash", { command: "echo $GIT_SEQUENCE_EDITOR" })])
    );

    const results = t.events.toolResultsFor("bash");
    expect(results[0].text).toContain("true");
  });

  it("actual command execution works with env vars", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
    });

    await t.run(
      when("dump env", [
        calls("bash", {
          command:
            'env | grep -E "^(GIT_EDITOR|GIT_SEQUENCE_EDITOR|GIT_PAGER|PAGER|LESS|BAT_PAGER)=" | sort',
        }),
      ])
    );

    const text = t.events.toolResultsFor("bash")[0].text;
    expect(text).toContain("BAT_PAGER=cat");
    expect(text).toContain("GIT_EDITOR=true");
    expect(text).toContain("GIT_PAGER=cat");
    expect(text).toContain("GIT_SEQUENCE_EDITOR=true");
    expect(text).toContain("LESS=-FX");
    expect(text).toContain("PAGER=cat");
  });

  it("blocks known interactive git commands", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
    });

    await t.run(when("interactive rebase", [calls("bash", { command: "git rebase -i HEAD~2" })]));

    const result = t.events.toolResultsFor("bash")[0];
    expect(result.isError).toBe(true);
    expect(result.text).toContain("Blocked interactive command");
    expect(result.text).toContain("Use instead");
  });

  it("does not block normal non-interactive command", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
    });

    await t.run(when("non interactive", [calls("bash", { command: "echo okay" })]));

    const result = t.events.toolResultsFor("bash")[0];
    expect(result.isError).toBe(false);
    expect(result.text).toContain("okay");
  });
});
