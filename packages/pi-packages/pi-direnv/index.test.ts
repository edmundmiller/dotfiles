import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

import direnvExtension from "./index.js";

type ExecCall = [command: string, args: string[], options?: { cwd?: string }];
type ExecResult = { stdout: string; stderr: string; code: number; killed: boolean };
type SessionHandler = (
  event: unknown,
  ctx: {
    sessionManager: { getCwd(): string };
    ui: { notify(message: string, type?: "info" | "warning" | "error"): void };
  }
) => Promise<void> | void;

function loadExtension(eventName: string, exec: (...call: ExecCall) => Promise<ExecResult>) {
  let handler: SessionHandler | undefined;
  const pi = {
    exec,
    on(event: string, callback: SessionHandler) {
      if (event === eventName) handler = callback;
    },
  };

  direnvExtension(pi as unknown as ExtensionAPI);
  if (!handler) throw new Error(`${eventName} handler was not registered`);
  return handler;
}

for (const eventName of ["session_start", "session_switch"]) {
  describe(`pi-direnv ${eventName}`, () => {
    const originalCwd = process.cwd();
    let tempDir: string;
    let projectDir: string;
    let sessionCwd: string;

    beforeEach(() => {
      tempDir = mkdtempSync(join(tmpdir(), "pi-direnv-test-"));
      projectDir = join(tempDir, "project");
      sessionCwd = join(projectDir, "src");
      mkdirSync(sessionCwd, { recursive: true });
      writeFileSync(join(projectDir, ".envrc"), "export PI_DIRENV_TEST_VALUE=loaded\n");
      // A different launch directory has its own .envrc, which must never be loaded.
      const launchDir = join(tempDir, "launch");
      mkdirSync(launchDir);
      writeFileSync(join(launchDir, ".envrc"), "export PI_DIRENV_TEST_VALUE=wrong\n");
      process.chdir(launchDir);
      Bun.spawnSync(["git", "init", "--quiet", projectDir]);
      delete process.env.PI_DIRENV_TEST_VALUE;
    });

    afterEach(() => {
      process.chdir(originalCwd);
      delete process.env.PI_DIRENV_TEST_VALUE;
      rmSync(tempDir, { recursive: true, force: true });
    });

    test("loads the session project environment rather than the launch directory", async () => {
      const calls: ExecCall[] = [];
      const notifications: Array<[string, string | undefined]> = [];
      const handler = loadExtension(eventName, async (...call) => {
        calls.push(call);
        const [command, args, options] = call;
        if (command === "git") {
          const result = Bun.spawnSync([command, ...args], options);
          return {
            stdout: result.stdout.toString(),
            stderr: result.stderr.toString(),
            code: result.exitCode,
            killed: false,
          };
        }
        if (command === "direnv") {
          return {
            stdout: JSON.stringify({
              PI_DIRENV_TEST_VALUE: options?.cwd === projectDir ? "loaded" : "wrong",
            }),
            stderr: "",
            code: 0,
            killed: false,
          };
        }
        return { stdout: "", stderr: "", code: 0, killed: false };
      });

      await handler(
        {},
        {
          sessionManager: { getCwd: () => sessionCwd },
          ui: { notify: (...args) => notifications.push(args) },
        }
      );

      expect(calls).toEqual([
        ["which", ["direnv"]],
        ["git", ["rev-parse", "--show-toplevel"], { cwd: sessionCwd }],
        ["direnv", ["export", "json"], { cwd: projectDir }],
      ]);
      expect(process.env.PI_DIRENV_TEST_VALUE).toBe("loaded");
      expect(notifications).toEqual([["direnv: loaded 1 env vars", "info"]]);
    });

    test("stops silently when direnv is missing", async () => {
      const calls: ExecCall[] = [];
      const notifications: Array<[string, string | undefined]> = [];
      const handler = loadExtension(eventName, async (...call) => {
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

      await handler(
        {},
        {
          sessionManager: { getCwd: () => sessionCwd },
          ui: { notify: (...args) => notifications.push(args) },
        }
      );

      expect(calls).toEqual([["which", ["direnv"]]]);
      expect(notifications).toEqual([]);
    });

    test("skips silently without a project .envrc and does not search past the git root", async () => {
      rmSync(join(projectDir, ".envrc"));
      writeFileSync(join(tempDir, ".envrc"), "export PI_DIRENV_TEST_VALUE=wrong\n");
      const notifications: string[] = [];
      const handler = loadExtension(eventName, async (command, args, options) => {
        if (command === "git") {
          const result = Bun.spawnSync([command, ...args], options);
          return {
            stdout: result.stdout.toString(),
            stderr: result.stderr.toString(),
            code: result.exitCode,
            killed: false,
          };
        }
        return {
          stdout: JSON.stringify({ PI_DIRENV_TEST_VALUE: "wrong" }),
          stderr: "",
          code: 0,
          killed: false,
        };
      });

      await handler(
        {},
        {
          sessionManager: { getCwd: () => sessionCwd },
          ui: { notify: (message) => notifications.push(message) },
        }
      );

      expect(process.env.PI_DIRENV_TEST_VALUE).toBeUndefined();
      expect(notifications).toEqual([]);
    });
  });
}
