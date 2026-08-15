import { describe, expect, test, afterEach } from "bun:test";
import { unlinkSync } from "node:fs";
import { dirname } from "node:path";
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

describe("gh revalidation (VAL-BRIDGE-009, 010, 011, 012, 021, 022)", () => {
  test("gh data overrides stale stdin hints (R10)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, {
      pr: {
        ...STD_GH_RESPONSE,
        headRefOid: "H_gh_aaaabbbbccccddddeeeeffff000011112222",
        headRefName: "B_gh",
        title: "T_gh",
      },
    });
    // stdin has stale values
    const stalePayload = JSON.stringify({
      repository: "edmundmiller/dotfiles",
      number: 216,
      headRefOid: "stale_oid_0000000000000000000000000000",
      headRefName: "stale_branch",
      title: "stale title",
      url: "https://github.com/edmundmiller/dotfiles/pull/216",
    });
    const result = await runCli(env, { stdin: stalePayload });
    expect(result.exitCode).toBe(0);
    const out = JSON.parse(result.stdout);
    expect(out.headRefOid).toBe("H_gh_aaaabbbbccccddddeeeeffff000011112222");
    expect(out.status).toBe("created");

    // Manifest should record gh's headRefOid
    const manifest = JSON.parse(await Bun.file(`${env.stateDir}/${STD_MANIFEST_KEY}.json`).text());
    expect(manifest.headRefOid).toBe("H_gh_aaaabbbbccccddddeeeeffff000011112222");

    // Workspace create should use gh's title
    const herdrCalls = readLog(env.herdrLog);
    const createCall = herdrCalls.find((c) => c.includes("workspace") && c.includes("create"));
    expect(createCall).toBeDefined();
    expect(createCall).toContain("T_gh");
  });

  test("exactly one read-only gh pr view call per run (VAL-BRIDGE-010)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    await runCli(env, { stdin: STD_PR_JSON });

    const ghCalls = readLog(env.ghLog);
    const viewCalls = ghCalls.filter((c) => c.startsWith("pr view "));
    expect(viewCalls).toHaveLength(1);
    // Exact field list check
    expect(viewCalls[0]).toContain("--json");
    expect(viewCalls[0]).toContain("number,title,baseRefName,headRefName,headRefOid,url,state");
    expect(viewCalls[0]).toContain("--repo");
    expect(viewCalls[0]).toContain("edmundmiller/dotfiles");
  });

  test("gh failure (non-zero exit) exits 4 with no side effects", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE, exitCode: 1, stderr: "gh: API error" });
    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(4);
    expect(result.stdout).toContain('"error"');
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(false);
    expect(readLog(env.herdrLog)).toHaveLength(0);
  });

  test("gh exit 0 but missing headRefOid exits 4", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    // Return JSON without headRefOid
    setGhProfile(env, {
      pr: {
        number: 216,
        title: "Test",
        baseRefName: "main",
        headRefName: "feature",
        url: "https://github.com/edmundmiller/dotfiles/pull/216",
        state: "OPEN",
        // missing headRefOid
      } as any,
    });
    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(4);
    expect(result.stdout).toContain('"error"');
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(false);
  });

  test("missing gh binary on PATH exits 4 (R1 ENOENT)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    // Remove gh from stub dir and exclude the user profile containing system gh.
    try {
      unlinkSync(`${env.stubDir}/gh`);
    } catch {}
    const bunDir = dirname(process.execPath);
    const result = await runCli(env, {
      stdin: STD_PR_JSON,
      extraEnv: { PATH: `${env.stubDir}:/bin:/usr/bin:${bunDir}` },
    });
    expect(result.exitCode).toBe(4);
    expect(result.stdout).toContain('"error"');
    expect(result.stderr).toContain("gh");
    // No stack trace
    expect(result.stderr).not.toContain("at ");
    expect(result.stdout).not.toContain("at ");
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(false);
  });

  test("non-OPEN (MERGED) PR exits 3 and opens nothing (VAL-BRIDGE-012)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: { ...STD_GH_RESPONSE, state: "MERGED" } });
    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(3);
    const out = JSON.parse(result.stdout);
    expect(out.status).toBe("closed");
    expect(out.state).toBe("MERGED");
    expect(readLog(env.herdrLog)).toHaveLength(0);
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(false);
  });

  test("non-OPEN (CLOSED) PR exits 3 and opens nothing", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: { ...STD_GH_RESPONSE, state: "CLOSED" } });
    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(3);
    const out = JSON.parse(result.stdout);
    expect(out.status).toBe("closed");
    expect(out.state).toBe("CLOSED");
    expect(readLog(env.herdrLog)).toHaveLength(0);
  });

  test("non-OPEN PR leaves pre-existing manifest byte-identical", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: { ...STD_GH_RESPONSE, state: "CLOSED" } });

    // Seed a manifest
    const { mkdirSync, writeFileSync } = await import("node:fs");
    const manifestPath = `${env.stateDir}/${STD_MANIFEST_KEY}.json`;
    const manifestContent =
      JSON.stringify(
        {
          schemaVersion: 1,
          repoRoot: env.repoRoot,
          prNumber: 216,
          prUrl: "https://github.com/edmundmiller/dotfiles/pull/216",
          headRefOid: "oldhead000000000000000000000000000000000000",
          worktreePath: "/tmp/old",
          workspaceId: "w-old",
          diffTarget: "origin/main...HEAD",
          agent: "omp",
          updatedAt: "2025-01-01T00:00:00.000Z",
        },
        null,
        2
      ) + "\n";
    writeFileSync(manifestPath, manifestContent);

    await runCli(env, { stdin: STD_PR_JSON });

    // Manifest should be byte-identical
    const after = await Bun.file(manifestPath).text();
    expect(after).toBe(manifestContent);
  });

  test("zero GitHub writes — only pr view and pr checkout (VAL-BRIDGE-021)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    await runCli(env, { stdin: STD_PR_JSON });

    const ghCalls = readLog(env.ghLog);
    for (const call of ghCalls) {
      const subcommand = call.split(" ")[1]; // e.g. "view" or "checkout"
      expect(["view", "checkout"]).toContain(subcommand);
    }
  });

  test("stdout is pure JSON — no human prose on stdout (VAL-BRIDGE-001 stdout purity)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(0);
    // stdout must be a single JSON object
    const parsed = JSON.parse(result.stdout);
    expect(parsed).toHaveProperty("status");
    expect(parsed).toHaveProperty("workspaceId");
    expect(parsed).toHaveProperty("worktreePath");
    expect(parsed).toHaveProperty("headRefOid");
    // stderr should have human-readable summary
    expect(result.stderr.length).toBeGreaterThan(0);
  });
});
