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
  readManifest,
  type Env,
} from "./helpers.js";

let env: Env | null = null;
afterEach(() => {
  if (env) {
    env.cleanup();
    env = null;
  }
});

describe("concurrency and lockfile (VAL-BRIDGE-028, 029, 037)", () => {
  test("concurrent same-PR runs serialize — one created, one resumed (VAL-BRIDGE-029)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    setHerdrProfile(env, { workspaceId: "w-concurrent", workspaceAlive: true, delayMs: 50 });

    // Launch two concurrent runs
    const [r1, r2] = await Promise.all([
      runCli(env, { stdin: STD_PR_JSON }),
      runCli(env, { stdin: STD_PR_JSON }),
    ]);

    expect(r1.exitCode).toBe(0);
    expect(r2.exitCode).toBe(0);

    const out1 = JSON.parse(r1.stdout);
    const out2 = JSON.parse(r2.stdout);

    // One created, one resumed (order doesn't matter)
    const statuses = [out1.status, out2.status].sort();
    expect(statuses).toEqual(["created", "resumed"]);

    // Only one manifest file
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(true);

    // No lockfile remaining
    const { existsSync } = await import("node:fs");
    expect(existsSync(`${env.stateDir}/${STD_MANIFEST_KEY}.lock`)).toBe(false);
  });

  test("stale lock is recovered without deadlock (VAL-BRIDGE-037)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    setHerdrProfile(env, { workspaceAlive: true });

    // Pre-create a stale lock with a dead PID
    const { writeFileSync, existsSync } = await import("node:fs");
    const lockPath = `${env.stateDir}/${STD_MANIFEST_KEY}.lock`;
    writeFileSync(lockPath, "999999"); // PID 999999 is almost certainly dead

    const start = Date.now();
    const result = await runCli(env, { stdin: STD_PR_JSON });
    const elapsed = Date.now() - start;

    expect(result.exitCode).toBe(0);
    expect(elapsed).toBeLessThan(30_000);
    expect(JSON.parse(result.stdout).status).toBe("created");

    // Lockfile cleaned up
    expect(existsSync(lockPath)).toBe(false);
    // Manifest exists
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(true);
  }, 30_000);

  test("stale lock with non-numeric content is recovered", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    setHerdrProfile(env, { workspaceAlive: true });

    const { writeFileSync, existsSync } = await import("node:fs");
    writeFileSync(`${env.stateDir}/${STD_MANIFEST_KEY}.lock`, "garbage");

    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(0);
    expect(existsSync(`${env.stateDir}/${STD_MANIFEST_KEY}.lock`)).toBe(false);
  });

  test("no orphaned lockfiles after successful run (VAL-BRIDGE-028a)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    setHerdrProfile(env, { workspaceAlive: true });

    await runCli(env, { stdin: STD_PR_JSON });

    const { existsSync, readdirSync } = await import("node:fs");
    const lockFiles = readdirSync(env.stateDir).filter((f) => f.endsWith(".lock"));
    expect(lockFiles).toHaveLength(0);
  });

  test("no stray temp files after successful run (VAL-BRIDGE-028b)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    setHerdrProfile(env, { workspaceAlive: true });

    await runCli(env, { stdin: STD_PR_JSON });

    const { readdirSync } = await import("node:fs");
    const tmpFiles = readdirSync(env.stateDir).filter((f) => f.endsWith(".tmp"));
    expect(tmpFiles).toHaveLength(0);
  });
});
