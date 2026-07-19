import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import direnvExtension from "./index.js";

type ExecCall = [command: string, args: string[], options?: { cwd?: string }];
type ExecResult = { stdout: string; stderr: string; code: number; killed: boolean };
type SessionStart = (
  event: unknown,
  ctx: { ui: { notify(message: string, type?: "info" | "warning" | "error"): void } }
) => Promise<void> | void;

function loadExtension(exec: (...call: ExecCall) => Promise<ExecResult>) {
  let sessionStart: SessionStart | undefined;
  const pi = {
    exec,
    on(event: string, handler: SessionStart) {
      if (event === "session_start") sessionStart = handler;
    },
  };

  direnvExtension(pi as unknown as ExtensionAPI);
  if (!sessionStart) throw new Error("session_start handler was not registered");
  return sessionStart;
}

function expectFailureUntilFixed(assertion: () => void, issue: string) {
  try {
    assertion();
  } catch {
    return;
  }
  throw new Error(`Unexpected pass for ${issue}; remove the expected-failure marker`);
}

describe("pi-direnv session_start", () => {
  const originalCwd = process.cwd();
  let projectDir: string;

  beforeEach(() => {
    projectDir = mkdtempSync(join(tmpdir(), "pi-direnv-test-"));
    writeFileSync(join(projectDir, ".envrc"), "export PI_DIRENV_TEST_VALUE=loaded\n");
    process.chdir(projectDir);
    projectDir = process.cwd();
  });

  afterEach(() => {
    process.chdir(originalCwd);
    delete process.env.PI_DIRENV_TEST_VALUE;
    rmSync(projectDir, { recursive: true, force: true });
  });

  test("passes executable and argv separately to pi.exec", async () => {
    const calls: ExecCall[] = [];
    const notifications: Array<[string, string | undefined]> = [];
    const sessionStart = loadExtension(async (...call) => {
      calls.push(call);
      const [command] = call;
      if (command === "git") {
        return { stdout: projectDir, stderr: "", code: 0, killed: false };
      }
      if (command === "direnv") {
        return {
          stdout: JSON.stringify({ PI_DIRENV_TEST_VALUE: "loaded" }),
          stderr: "",
          code: 0,
          killed: false,
        };
      }
      return { stdout: "", stderr: "", code: 0, killed: false };
    });

    await sessionStart({}, { ui: { notify: (...args) => notifications.push(args) } });

    expect(calls).toEqual([
      ["which", ["direnv"]],
      ["git", ["rev-parse", "--show-toplevel"]],
      ["direnv", ["export", "json"], { cwd: projectDir }],
    ]);
    expect(process.env.PI_DIRENV_TEST_VALUE).toBe("loaded");
    expect(notifications).toEqual([["direnv: loaded 1 env vars", "info"]]);
  });

  test("stops silently when direnv is missing", async () => {
    const calls: ExecCall[] = [];
    const notifications: Array<[string, string | undefined]> = [];
    const sessionStart = loadExtension(async (...call) => {
      calls.push(call);
      const [command] = call;
      if (command === "which") {
        return { stdout: "", stderr: "", code: 1, killed: false };
      }
      if (command === "git") {
        return { stdout: projectDir, stderr: "", code: 0, killed: false };
      }
      return { stdout: "{}", stderr: "", code: 0, killed: false };
    });

    await sessionStart({}, { ui: { notify: (...args) => notifications.push(args) } });

    expectFailureUntilFixed(() => {
      expect(calls).toEqual([["which", ["direnv"]]]);
      expect(notifications).toEqual([]);
    }, "GitHub issue #168");
  });
});
