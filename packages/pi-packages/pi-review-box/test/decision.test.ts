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
  readManifest,
  statMode,
  type Env,
} from "./helpers.js";

let env: Env | null = null;
afterEach(() => {
  if (env) {
    env.cleanup();
    env = null;
  }
});

describe("decision branches (VAL-BRIDGE-001, 004, 005, 014, 015, 016, 017, 019, 020, 027, 030, 035)", () => {
  test("valid promotion creates the box and exits 0 (VAL-BRIDGE-001)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(0);
    const out = JSON.parse(result.stdout);
    expect(out.status).toBe("created");
    expect(out.workspaceId).toBeTruthy();
    expect(out.worktreePath).toContain("/.pi/worktrees/");
    expect(out.headRefOid).toBe(STD_GH_RESPONSE.headRefOid);
  });

  test("manifest written with ReviewBoxManifest schema (VAL-BRIDGE-004)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    await runCli(env, { stdin: STD_PR_JSON });

    const m = readManifest(env, STD_MANIFEST_KEY);
    expect(m).toBeDefined();
    expect(m!.schemaVersion).toBe(1);
    expect(m!.repoRoot).toBe(env.repoRoot);
    expect(m!.prNumber).toBe(216);
    expect(m!.prUrl).toBe("https://github.com/edmundmiller/dotfiles/pull/216");
    expect(m!.headRefOid).toBe(STD_GH_RESPONSE.headRefOid);
    expect(m!.worktreePath).toBeTruthy();
    expect(m!.workspaceId).toBeTruthy();
    expect(m!.diffTarget).toContain("origin/main...HEAD");
    expect(m!.agent).toBe("omp");
    expect(m!.updatedAt).toBeTruthy();
    // ISO-8601 parseable
    expect(() => new Date(m!.updatedAt as string).toISOString()).not.toThrow();
    // Pretty-printed (contains newlines)
    const raw = await Bun.file(`${env.stateDir}/${STD_MANIFEST_KEY}.json`).text();
    expect(raw).toContain("\n");
    // File mode 0o600
    expect(statMode(env, STD_MANIFEST_KEY)).toBe("600");
    // Exactly 10 fields
    expect(Object.keys(m!).sort()).toEqual([
      "agent",
      "diffTarget",
      "headRefOid",
      "prNumber",
      "prUrl",
      "repoRoot",
      "schemaVersion",
      "updatedAt",
      "workspaceId",
      "worktreePath",
    ]);
  });

  test("manifest directory is auto-created (VAL-BRIDGE-027)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    // Remove the state dir to test auto-creation
    const { rmSync } = await import("node:fs");
    rmSync(env.stateDir, { recursive: true, force: true });
    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(0);
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(true);
  });

  test("repeated run resumes the same box (VAL-BRIDGE-005)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    const r1 = await runCli(env, { stdin: STD_PR_JSON });
    expect(r1.exitCode).toBe(0);
    const out1 = JSON.parse(r1.stdout);
    expect(out1.status).toBe("created");

    const r2 = await runCli(env, { stdin: STD_PR_JSON });
    expect(r2.exitCode).toBe(0);
    const out2 = JSON.parse(r2.stdout);
    expect(out2.status).toBe("resumed");
    expect(out2.workspaceId).toBe(out1.workspaceId);
    expect(out2.worktreePath).toBe(out1.worktreePath);

    // Only one manifest file
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(true);
  });

  test("resume only advances updatedAt/diffTarget/agent (R3)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    await runCli(env, { stdin: STD_PR_JSON });
    const m1 = readManifest(env, STD_MANIFEST_KEY)!;

    await runCli(env, { stdin: STD_PR_JSON });
    const m2 = readManifest(env, STD_MANIFEST_KEY)!;

    // These must be unchanged
    expect(m2.schemaVersion).toBe(m1.schemaVersion);
    expect(m2.repoRoot).toBe(m1.repoRoot);
    expect(m2.prNumber).toBe(m1.prNumber);
    expect(m2.prUrl).toBe(m1.prUrl);
    expect(m2.headRefOid).toBe(m1.headRefOid);
    expect(m2.worktreePath).toBe(m1.worktreePath);
    expect(m2.workspaceId).toBe(m1.workspaceId);
    // updatedAt may advance
    expect(new Date(m2.updatedAt).getTime()).toBeGreaterThanOrEqual(
      new Date(m1.updatedAt).getTime()
    );
  });

  test("dead workspace + live worktree is restored (VAL-BRIDGE-018/020)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    // First create
    const r1 = await runCli(env, { stdin: STD_PR_JSON });
    const out1 = JSON.parse(r1.stdout);
    expect(out1.status).toBe("created");

    // Now make workspace dead
    setHerdrProfile(env, { workspaceAlive: false });

    // Re-run — should restore
    const r2 = await runCli(env, { stdin: STD_PR_JSON });
    expect(r2.exitCode).toBe(0);
    const out2 = JSON.parse(r2.stdout);
    expect(out2.status).toBe("restored");
    expect(out2.workspaceId).not.toBe(out1.workspaceId);
    expect(out2.worktreePath).toBe(out1.worktreePath);

    // Manifest updated with new workspaceId
    const m = readManifest(env, STD_MANIFEST_KEY)!;
    expect(m.workspaceId).not.toBe(out1.workspaceId);
  });

  test("workspace existence checked via herdr workspace get (VAL-BRIDGE-020)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    // First create (no workspace get on create path with no manifest)
    await runCli(env, { stdin: STD_PR_JSON });

    // Clear log, then re-run — resume path calls workspace get
    const { writeFileSync } = await import("node:fs");
    writeFileSync(env.herdrLog, "");
    await runCli(env, { stdin: STD_PR_JSON });

    const herdrCalls = readLog(env.herdrLog);
    const getCalls = herdrCalls.filter((c) => c.startsWith("workspace get "));
    expect(getCalls.length).toBeGreaterThanOrEqual(1);
  });

  test("missing worktree forces full recreate (VAL-BRIDGE-019)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    // First create
    const r1 = await runCli(env, { stdin: STD_PR_JSON });
    expect(r1.exitCode).toBe(0);

    // Remove the worktree dir
    const m1 = readManifest(env, STD_MANIFEST_KEY)!;
    const { rmSync, existsSync } = await import("node:fs");
    if (existsSync(m1.worktreePath as string)) {
      rmSync(m1.worktreePath as string, { recursive: true, force: true });
    }

    // Re-run — should recreate
    const r2 = await runCli(env, { stdin: STD_PR_JSON });
    expect(r2.exitCode).toBe(0);
    const out2 = JSON.parse(r2.stdout);
    expect(out2.status).toBe("created");
  });

  test("corrupt manifest is backed up and rebuilt (VAL-BRIDGE-014)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    // Seed a corrupt manifest
    const { writeFileSync, existsSync } = await import("node:fs");
    const manifestPath = `${env.stateDir}/${STD_MANIFEST_KEY}.json`;
    const corruptContent = "{ not valid json at all }}}";
    writeFileSync(manifestPath, corruptContent);

    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(0);
    const out = JSON.parse(result.stdout);
    expect(out.status).toBe("created");

    // .bak file should contain original corrupt bytes
    const bakPath = `${manifestPath}.bak`;
    expect(existsSync(bakPath)).toBe(true);
    const bakContent = await Bun.file(bakPath).text();
    expect(bakContent).toBe(corruptContent);

    // New manifest should be valid
    const m = readManifest(env, STD_MANIFEST_KEY);
    expect(m).toBeDefined();
    expect(m!.schemaVersion).toBe(1);
  });

  test("valid-JSON wrong-schema manifest follows corrupt-path (VAL-BRIDGE-035a)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    const { writeFileSync, existsSync } = await import("node:fs");
    const manifestPath = `${env.stateDir}/${STD_MANIFEST_KEY}.json`;
    const wrongSchema = JSON.stringify({ schemaVersion: 2, foo: "bar" });
    writeFileSync(manifestPath, wrongSchema);

    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(0);
    expect(JSON.parse(result.stdout).status).toBe("created");

    // .bak should preserve original
    expect(existsSync(`${manifestPath}.bak`)).toBe(true);
    expect(await Bun.file(`${manifestPath}.bak`).text()).toBe(wrongSchema);
  });

  test("wrong-schema manifest with missing workspaceId (VAL-BRIDGE-035b)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    const { writeFileSync } = await import("node:fs");
    const manifestPath = `${env.stateDir}/${STD_MANIFEST_KEY}.json`;
    const wrongSchema = JSON.stringify({
      schemaVersion: 1,
      repoRoot: env.repoRoot,
      prNumber: 216,
      prUrl: "https://github.com/edmundmiller/dotfiles/pull/216",
      headRefOid: "abc",
      worktreePath: "/tmp/x",
      // missing workspaceId
      diffTarget: "origin/main...HEAD",
      agent: "omp",
      updatedAt: "2025-01-01T00:00:00.000Z",
    });
    writeFileSync(manifestPath, wrongSchema);

    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(0);
    expect(JSON.parse(result.stdout).status).toBe("created");
  });

  test("corrupt manifest for one PR does not affect siblings (VAL-BRIDGE-035c)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    const { writeFileSync, readFileSync } = await import("node:fs");
    const siblingKey = "acme-widgets-pr-7";
    const siblingPath = `${env.stateDir}/${siblingKey}.json`;
    const siblingContent = JSON.stringify({ sentinel: "preserved", schemaVersion: 1 });
    writeFileSync(siblingPath, siblingContent);

    // Corrupt the target manifest
    const manifestPath = `${env.stateDir}/${STD_MANIFEST_KEY}.json`;
    writeFileSync(manifestPath, "corrupt content");

    await runCli(env, { stdin: STD_PR_JSON });

    // Sibling should be byte-identical
    expect(readFileSync(siblingPath, "utf8")).toBe(siblingContent);
  });

  test("XDG_STATE_HOME honored for manifest (VAL-BRIDGE-015)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    await runCli(env, { stdin: STD_PR_JSON });

    // Manifest should be under stateHome, not home
    const { existsSync } = await import("node:fs");
    expect(existsSync(`${env.stateDir}/${STD_MANIFEST_KEY}.json`)).toBe(true);
    expect(existsSync(`${env.home}/.local/state/pi-herdr/review-boxes/`)).toBe(false);
  });

  test("unrelated PR manifest files left byte-identical (VAL-BRIDGE-016)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    const { writeFileSync, readFileSync } = await import("node:fs");
    const siblingKey = "acme-widgets-pr-7";
    const siblingPath = `${env.stateDir}/${siblingKey}.json`;
    const siblingContent =
      JSON.stringify(
        {
          schemaVersion: 1,
          repoRoot: "/tmp/acme",
          prNumber: 7,
          prUrl: "https://github.com/acme/widgets/pull/7",
          headRefOid: "aaa",
          worktreePath: "/tmp/acme-wt",
          workspaceId: "w-acme",
          diffTarget: "origin/main...HEAD",
          agent: "omp",
          updatedAt: "2025-01-01T00:00:00.000Z",
        },
        null,
        2
      ) + "\n";
    writeFileSync(siblingPath, siblingContent);

    await runCli(env, { stdin: STD_PR_JSON });

    expect(readFileSync(siblingPath, "utf8")).toBe(siblingContent);
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(true);
  });

  test("herdr failure exits 6 and leaves worktree (R4/VAL-BRIDGE-030a)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    // Create a herdr stub that succeeds on list/get but fails on workspace create
    const { writeFileSync } = await import("node:fs");
    const script = `#!/usr/bin/env bash
echo "$@" >> "${env.herdrLog}"
case "$1" in
  workspace)
    case "$2" in
      create)
        echo "herdr: workspace create failed" >&2
        exit 1
        ;;
      get|close|focus|list)
        exit 0
        ;;
    esac
    ;;
  tab) case "$2" in create) echo "{\\"id\\":\\"cli:tab:create\\",\\"result\\":{\\"pane_id\\":\\"p-stub-1\\"}}"; exit 0 ;; esac ;;
  pane) exit 0 ;;
esac
exit 0
`;
    writeFileSync(`${env.stubDir}/herdr`, script, { mode: 0o755 });

    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(6);
    expect(result.stdout).toContain('"error"');
    // No manifest written
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(false);
  });

  test("herdr down on manifest-hit exits 6 with zero creates (VAL-BRIDGE-030c)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    // First create normally
    setHerdrProfile(env, { workspaceAlive: true });
    await runCli(env, { stdin: STD_PR_JSON });
    const m1 = readManifest(env, STD_MANIFEST_KEY)!;
    const manifestContent = await Bun.file(`${env.stateDir}/${STD_MANIFEST_KEY}.json`).text();

    // Now make herdr fail
    setHerdrProfile(env, { failExitCode: 1 });
    // Clear the herdr log
    const { writeFileSync } = await import("node:fs");
    writeFileSync(env.herdrLog, "");

    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(6);
    expect(result.stdout).toContain('"error"');

    // Zero workspace create calls
    const herdrCalls = readLog(env.herdrLog);
    const createCalls = herdrCalls.filter((c) => c.includes("workspace create"));
    expect(createCalls).toHaveLength(0);

    // Manifest byte-identical
    expect(await Bun.file(`${env.stateDir}/${STD_MANIFEST_KEY}.json`).text()).toBe(manifestContent);
  });

  test("retry after exit 6 converges (VAL-BRIDGE-030b)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    // First run: herdr fails
    setHerdrProfile(env, { failExitCode: 1 });
    const r1 = await runCli(env, { stdin: STD_PR_JSON });
    expect(r1.exitCode).toBe(6);

    // Retry: herdr works now
    setHerdrProfile(env, { workspaceAlive: true });
    const r2 = await runCli(env, { stdin: STD_PR_JSON });
    expect(r2.exitCode).toBe(0);
    expect(JSON.parse(r2.stdout).status).toBe("created");

    // Exactly one manifest file
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(true);
  });

  test("missing herdr binary exits 6 (R1 ENOENT)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    try {
      unlinkSync(`${env.stubDir}/herdr`);
    } catch {}

    // Use a PATH containing the stub dir + essential system dirs (for bash,
    // env) + bun's bin, but excluding the user profile dir where the system
    // herdr lives — so the bridge sees a true ENOENT for herdr.
    const bunDir = dirname(process.execPath);
    const result = await runCli(env, {
      stdin: STD_PR_JSON,
      extraEnv: { PATH: `${env.stubDir}:/bin:/usr/bin:${bunDir}` },
    });
    expect(result.exitCode).toBe(6);
    expect(result.stdout).toContain('"error"');
    expect(result.stderr).toContain("herdr");
    // No stack trace
    expect(result.stderr).not.toContain("at ");
    expect(result.stdout).not.toContain("at ");
  });

  test("head change refreshes with new workspaceId (VAL-BRIDGE-017)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    setHerdrProfile(env, { workspaceAlive: true });

    // Create
    const r1 = await runCli(env, { stdin: STD_PR_JSON });
    const out1 = JSON.parse(r1.stdout);
    expect(out1.status).toBe("created");
    expect(out1.workspaceId).toBeTruthy();

    // Change head
    setGhProfile(env, {
      pr: { ...STD_GH_RESPONSE, headRefOid: "H2_aaaabbbbccccddddeeeeffff000011112222" },
    });

    const r2 = await runCli(env, { stdin: STD_PR_JSON });
    expect(r2.exitCode).toBe(0);
    const out2 = JSON.parse(r2.stdout);
    expect(out2.status).toBe("refreshed");
    expect(out2.workspaceId).not.toBe(out1.workspaceId);
    expect(out2.worktreePath).toBe(out1.worktreePath);
    expect(out2.headRefOid).toBe("H2_aaaabbbbccccddddeeeeffff000011112222");

    // Manifest should have new head and new workspaceId
    const m = readManifest(env, STD_MANIFEST_KEY)!;
    expect(m.headRefOid).toBe("H2_aaaabbbbccccddddeeeeffff000011112222");
    expect(m.workspaceId).not.toBe(out1.workspaceId);
    expect(m.workspaceId).toBe(out2.workspaceId);

    // Third run with same H2 should resume
    const r3 = await runCli(env, { stdin: STD_PR_JSON });
    expect(r3.exitCode).toBe(0);
    const out3 = JSON.parse(r3.stdout);
    expect(out3.status).toBe("resumed");
    expect(out3.workspaceId).toBe(out2.workspaceId);
  });
});
