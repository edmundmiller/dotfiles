import { describe, expect, test, afterEach } from "bun:test";
import {
  setupEnv,
  runCli,
  setGhProfile,
  setHerdrProfile,
  readLog,
  STD_PR_JSON,
  STD_GH_RESPONSE,
  STD_MANIFEST_KEY,
  manifestExists,
  type Env,
} from "./helpers.js";

let env: Env | null = null;
afterEach(() => {
  if (env) {
    env.cleanup();
    env = null;
  }
});

describe("timeouts (VAL-BRIDGE-022, 036)", () => {
  test("hung gh bounded by 30s timeout exits 4 (VAL-BRIDGE-022)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE, delayMs: 120_000 });

    const start = Date.now();
    const result = await runCli(env, { stdin: STD_PR_JSON });
    const elapsed = Date.now() - start;

    expect(result.exitCode).toBe(4);
    expect(result.stdout).toContain('"error"');
    expect(elapsed).toBeLessThan(60_000);
    // No manifest
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(false);
  }, 65_000);

  test("herdr timeout bounded exits 6 (VAL-BRIDGE-036a)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    setHerdrProfile(env, { delayMs: 120_000, failExitCode: 0 });

    // Override herdr stub to sleep but return exit 0 eventually (killed before)
    const { writeFileSync } = await import("node:fs");
    const script = `#!/usr/bin/env bash
echo "$@" >> "${env.herdrLog}"
sleep 120
exit 0
`;
    writeFileSync(`${env.stubDir}/herdr`, script, { mode: 0o755 });

    const start = Date.now();
    const result = await runCli(env, { stdin: STD_PR_JSON });
    const elapsed = Date.now() - start;

    expect(result.exitCode).toBe(6);
    expect(result.stdout).toContain('"error"');
    expect(elapsed).toBeLessThan(30_000);
  }, 35_000);

  test("git timeout bounded exits 6 (VAL-BRIDGE-036b)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    setHerdrProfile(env, { workspaceAlive: true });

    // Override git stub to sleep
    const { writeFileSync } = await import("node:fs");
    const script = `#!/usr/bin/env bash
echo "$@" >> "${env.gitLog}"
sleep 120
exit 0
`;
    writeFileSync(`${env.stubDir}/git`, script, { mode: 0o755 });

    const start = Date.now();
    const result = await runCli(env, { stdin: STD_PR_JSON });
    const elapsed = Date.now() - start;

    expect(result.exitCode).toBe(6);
    expect(result.stdout).toContain('"error"');
    expect(elapsed).toBeLessThan(90_000);
  }, 95_000);
});
