import { describe, expect, test, afterEach } from "bun:test";
import { writeFileSync } from "node:fs";
import {
  setupEnv,
  runCli,
  setGhProfile,
  setHerdrProfile,
  readLog,
  STD_GH_RESPONSE,
  STD_MANIFEST_KEY,
  readManifest,
  listStateFiles,
  type Env,
} from "./helpers.js";

let env: Env | null = null;
afterEach(() => {
  if (env) {
    env.cleanup();
    env = null;
  }
});

function seedManifest(
  env: Env,
  key: string,
  opts: { workspaceId?: string; worktreePath?: string }
): void {
  const manifest = {
    schemaVersion: 1,
    repoRoot: env.repoRoot,
    prNumber: 216,
    prUrl: `https://github.com/${key.replace(/-pr-\d+$/, "").replace(/-/g, "/")}/pull/216`,
    headRefOid: "abc123def456",
    worktreePath: opts.worktreePath ?? "/tmp/nonexistent-worktree",
    workspaceId: opts.workspaceId ?? "w-test",
    diffTarget: "origin/main...HEAD",
    agent: "omp",
    updatedAt: "2025-01-01T00:00:00.000Z",
  };
  writeFileSync(`${env.stateDir}/${key}.json`, JSON.stringify(manifest, null, 2) + "\n");
}

describe("prune (VAL-BRIDGE-023, 024, 025)", () => {
  test("removes manifest whose workspace AND worktree are both gone (VAL-BRIDGE-023)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setHerdrProfile(env, { workspaceAlive: false });

    // Seed a manifest pointing to nonexistent worktree and dead workspace
    seedManifest(env, STD_MANIFEST_KEY, {
      workspaceId: "w-gone",
      worktreePath: "/tmp/nonexistent-wt",
    });

    const result = await runCli(env, { args: ["prune"] });
    expect(result.exitCode).toBe(0);
    const out = JSON.parse(result.stdout);
    expect(out.removed).toContain(STD_MANIFEST_KEY);
    expect(listStateFiles(env)).not.toContain(`${STD_MANIFEST_KEY}.json`);

    // Zero gh calls
    expect(readLog(env.ghLog)).toHaveLength(0);
  });

  test("keeps manifest when workspace alive (VAL-BRIDGE-024a)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setHerdrProfile(env, { workspaceAlive: true });

    const beforeContent =
      JSON.stringify(
        {
          schemaVersion: 1,
          repoRoot: env.repoRoot,
          prNumber: 216,
          prUrl: "https://github.com/edmundmiller/dotfiles/pull/216",
          headRefOid: "abc",
          worktreePath: "/tmp/nonexistent",
          workspaceId: "w-alive",
          diffTarget: "origin/main...HEAD",
          agent: "omp",
          updatedAt: "2025-01-01T00:00:00.000Z",
        },
        null,
        2
      ) + "\n";

    const { writeFileSync, readFileSync } = await import("node:fs");
    writeFileSync(`${env.stateDir}/${STD_MANIFEST_KEY}.json`, beforeContent);

    const result = await runCli(env, { args: ["prune"] });
    expect(result.exitCode).toBe(0);
    const out = JSON.parse(result.stdout);
    expect(out.removed).not.toContain(STD_MANIFEST_KEY);

    // File byte-identical
    expect(readFileSync(`${env.stateDir}/${STD_MANIFEST_KEY}.json`, "utf8")).toBe(beforeContent);
  });

  test("keeps manifest when worktree present (VAL-BRIDGE-024b)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setHerdrProfile(env, { workspaceAlive: false });

    // Create a worktree dir that exists
    const { mkdirSync, writeFileSync, readFileSync, existsSync } = await import("node:fs");
    const wtPath = `${env.repoRoot}/.pi/worktrees/pr-216-feature-branch`;
    mkdirSync(wtPath, { recursive: true });

    const beforeContent =
      JSON.stringify(
        {
          schemaVersion: 1,
          repoRoot: env.repoRoot,
          prNumber: 216,
          prUrl: "https://github.com/edmundmiller/dotfiles/pull/216",
          headRefOid: "abc",
          worktreePath: wtPath,
          workspaceId: "w-dead",
          diffTarget: "origin/main...HEAD",
          agent: "omp",
          updatedAt: "2025-01-01T00:00:00.000Z",
        },
        null,
        2
      ) + "\n";
    writeFileSync(`${env.stateDir}/${STD_MANIFEST_KEY}.json`, beforeContent);

    const result = await runCli(env, { args: ["prune"] });
    expect(result.exitCode).toBe(0);
    const out = JSON.parse(result.stdout);
    expect(out.removed).not.toContain(STD_MANIFEST_KEY);
    expect(readFileSync(`${env.stateDir}/${STD_MANIFEST_KEY}.json`, "utf8")).toBe(beforeContent);
  });

  test("tolerates missing state dir (VAL-BRIDGE-025a)", async () => {
    env = setupEnv({});
    const { rmSync, existsSync } = await import("node:fs");
    rmSync(env.stateDir, { recursive: true, force: true });

    const result = await runCli(env, { args: ["prune"] });
    expect(result.exitCode).toBe(0);
    const out = JSON.parse(result.stdout);
    expect(out.removed).toEqual([]);
  });

  test("tolerates corrupt manifest files (VAL-BRIDGE-025b)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setHerdrProfile(env, { workspaceAlive: false });

    const { writeFileSync, existsSync } = await import("node:fs");
    const manifestPath = `${env.stateDir}/${STD_MANIFEST_KEY}.json`;
    const corruptContent = "corrupt json {{{";
    writeFileSync(manifestPath, corruptContent);

    const result = await runCli(env, { args: ["prune"] });
    expect(result.exitCode).toBe(0);
    const out = JSON.parse(result.stdout);
    // Corrupt file is kept (unparseable targets)
    expect(out.removed).not.toContain(STD_MANIFEST_KEY);
    // .bak file created
    expect(existsSync(`${manifestPath}.bak`)).toBe(true);
    expect(await Bun.file(`${manifestPath}.bak`).text()).toBe(corruptContent);
  });

  test("no-op run with all alive exits 0 (VAL-BRIDGE-025c)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setHerdrProfile(env, { workspaceAlive: true });

    const { writeFileSync, readFileSync, mkdirSync } = await import("node:fs");
    const wtPath = `${env.repoRoot}/.pi/worktrees/pr-216-feature-branch`;
    mkdirSync(wtPath, { recursive: true });

    const content =
      JSON.stringify(
        {
          schemaVersion: 1,
          repoRoot: env.repoRoot,
          prNumber: 216,
          prUrl: "https://github.com/edmundmiller/dotfiles/pull/216",
          headRefOid: "abc",
          worktreePath: wtPath,
          workspaceId: "w-alive",
          diffTarget: "origin/main...HEAD",
          agent: "omp",
          updatedAt: "2025-01-01T00:00:00.000Z",
        },
        null,
        2
      ) + "\n";
    writeFileSync(`${env.stateDir}/${STD_MANIFEST_KEY}.json`, content);

    const result = await runCli(env, { args: ["prune"] });
    expect(result.exitCode).toBe(0);
    const out = JSON.parse(result.stdout);
    expect(out.removed).toEqual([]);
    // File byte-identical
    expect(readFileSync(`${env.stateDir}/${STD_MANIFEST_KEY}.json`, "utf8")).toBe(content);
  });

  test("prune with herdr down exits 6 (VAL-BRIDGE-030a sub-case)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setHerdrProfile(env, { failExitCode: 1 });

    const { writeFileSync } = await import("node:fs");
    const content =
      JSON.stringify(
        {
          schemaVersion: 1,
          repoRoot: env.repoRoot,
          prNumber: 216,
          prUrl: "https://github.com/edmundmiller/dotfiles/pull/216",
          headRefOid: "abc",
          worktreePath: "/tmp/nonexistent",
          workspaceId: "w-test",
          diffTarget: "origin/main...HEAD",
          agent: "omp",
          updatedAt: "2025-01-01T00:00:00.000Z",
        },
        null,
        2
      ) + "\n";
    writeFileSync(`${env.stateDir}/${STD_MANIFEST_KEY}.json`, content);

    const result = await runCli(env, { args: ["prune"] });
    expect(result.exitCode).toBe(6);
    // All manifest files kept
    expect(listStateFiles(env)).toContain(`${STD_MANIFEST_KEY}.json`);
  });
});
