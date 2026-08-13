import { describe, expect, test, beforeEach, afterEach } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

/**
 * Unit tests for the exported decision flow (openReviewBox), the gh fetch
 * helper (fetchPrInfo), the R2 per-PR lockfile (stale reclaim, cleanup), and
 * R4 worktree tolerance.
 */

import {
  openReviewBox,
  fetchPrInfo,
  prepareReviewWorktree,
  type ExecFn,
  type PrInfo,
} from "./pr-review-workspace.js";

// ─── Fixed PR fixture ────────────────────────────────────────────────

const F = {
  prNumber: 42,
  prTitle: "Fix all the bugs",
  prUrl: "https://github.com/acme/widget/pull/42",
  baseRefName: "main",
  headRefName: "feature-branch",
  headRefOid: "abc123def456789012345678901234567890abcd",
  workspaceId: "wABC",
} as const;

const prInfo: PrInfo = {
  number: F.prNumber,
  title: F.prTitle,
  baseRefName: F.baseRefName,
  headRefName: F.headRefName,
  headRefOid: F.headRefOid,
  url: F.prUrl,
};

const manifestKey = "acme-widget-pr-42";
const worktreeSlug = "pr-42-feature-branch";

// ─── Test-scoped state ───────────────────────────────────────────────

let tempDir: string;
let repoRoot: string;
let stateRoot: string;
let worktreePath: string;
let lockPath: string;
let oldXdgStateHome: string | undefined;

beforeEach(() => {
  tempDir = mkdtempSync(join(tmpdir(), "pi-herdr-orb-"));
  repoRoot = join(tempDir, "widget");
  stateRoot = join(tempDir, "state", "pi-herdr", "review-boxes");
  worktreePath = join(repoRoot, ".pi", "worktrees", worktreeSlug);
  lockPath = join(stateRoot, `${manifestKey}.lock`);
  mkdirSync(join(repoRoot, ".git"), { recursive: true });
  oldXdgStateHome = process.env.XDG_STATE_HOME;
  process.env.XDG_STATE_HOME = join(tempDir, "state");
});

afterEach(() => {
  if (oldXdgStateHome === undefined) delete process.env.XDG_STATE_HOME;
  else process.env.XDG_STATE_HOME = oldXdgStateHome;
  rmSync(tempDir, { recursive: true, force: true });
});

// ─── Canned exec stub ────────────────────────────────────────────────

function createExecStub(
  opts: {
    workspaceGetSucceeds?: boolean;
    checkoutFailFirst?: boolean;
  } = {}
): { exec: ExecFn; calls: Array<{ cmd: string; args: string[] }> } {
  const calls: Array<{ cmd: string; args: string[] }> = [];
  let tabCounter = 0;
  let checkoutAttempts = 0;

  const exec: ExecFn = async (cmd, args, _opts) => {
    calls.push({ cmd, args });

    if (cmd === "git" && args[0] === "rev-parse" && args[1] === "--show-toplevel")
      return { stdout: `${repoRoot}\n`, stderr: "", code: 0 };
    if (cmd === "git" && args[0] === "rev-parse" && args.includes("--git-common-dir"))
      return { stdout: `${join(repoRoot, ".git")}\n`, stderr: "", code: 0 };
    if (cmd === "gh" && args[0] === "pr" && args[1] === "view")
      return {
        stdout: JSON.stringify({
          number: F.prNumber,
          title: F.prTitle,
          baseRefName: F.baseRefName,
          headRefName: F.headRefName,
          headRefOid: F.headRefOid,
          url: F.prUrl,
        }),
        stderr: "",
        code: 0,
      };
    if (cmd === "git" && args[0] === "fetch") return { stdout: "", stderr: "", code: 0 };
    if (cmd === "git" && args[0] === "worktree" && args[1] === "add") {
      mkdirSync(args[3], { recursive: true });
      return { stdout: "", stderr: "", code: 0 };
    }
    if (cmd === "git" && args[0] === "worktree" && args[1] === "prune")
      return { stdout: "", stderr: "", code: 0 };
    if (cmd === "gh" && args[0] === "pr" && args[1] === "checkout") {
      checkoutAttempts++;
      if (opts.checkoutFailFirst && checkoutAttempts === 1)
        return { stdout: "", stderr: "not a git worktree", code: 1 };
      return { stdout: "", stderr: "", code: 0 };
    }
    if (cmd === "herdr" && args[0] === "workspace" && args[1] === "create")
      return { stdout: JSON.stringify({ workspace_id: F.workspaceId }), stderr: "", code: 0 };
    if (cmd === "herdr" && args[0] === "workspace" && args[1] === "get") {
      if (opts.workspaceGetSucceeds === false) return { stdout: "", stderr: "not found", code: 1 };
      return { stdout: JSON.stringify({ workspace_id: F.workspaceId }), stderr: "", code: 0 };
    }
    if (cmd === "herdr" && args[0] === "workspace" && args[1] === "close")
      return { stdout: "", stderr: "", code: 0 };
    if (cmd === "herdr" && args[0] === "tab" && args[1] === "create") {
      tabCounter++;
      return {
        stdout: JSON.stringify({ pane_id: `${F.workspaceId}-${tabCounter}` }),
        stderr: "",
        code: 0,
      };
    }
    if (cmd === "herdr" && args[0] === "pane") return { stdout: "", stderr: "", code: 0 };
    if (cmd === "herdr" && args[0] === "workspace" && args[1] === "focus")
      return { stdout: "", stderr: "", code: 0 };
    if (cmd === "git" && args[0] === "rev-parse" && args[1] === "HEAD")
      return { stdout: `${F.headRefOid}\n`, stderr: "", code: 0 };
    return { stdout: "", stderr: "", code: 0 };
  };

  return { exec, calls };
}

function seedManifest(headRefOid: string): void {
  mkdirSync(stateRoot, { recursive: true });
  const manifest = {
    schemaVersion: 1,
    repoRoot,
    prNumber: F.prNumber,
    prUrl: F.prUrl,
    headRefOid,
    worktreePath,
    workspaceId: F.workspaceId,
    diffTarget: `origin/${F.baseRefName}...HEAD`,
    agent: "omp",
    updatedAt: "2025-01-01T00:00:00.000Z",
  };
  writeFileSync(join(stateRoot, `${manifestKey}.json`), JSON.stringify(manifest, null, 2) + "\n");
}

function seedWorktree(): void {
  mkdirSync(worktreePath, { recursive: true });
}

// ─── Tests: openReviewBox exports and decision flow ──────────────────

describe("openReviewBox", () => {
  test("is exported as a function", () => {
    expect(typeof openReviewBox).toBe("function");
  });

  test("create path: no manifest → creates worktree + workspace, writes manifest", async () => {
    const { exec, calls } = createExecStub({ workspaceGetSucceeds: true });

    const result = await openReviewBox(exec, {
      pr: prInfo,
      repoRoot,
      sharedRoot: repoRoot,
      prIdentifier: "42",
      stateRoot,
    });

    expect(result.action).toBe("created");
    expect(result.workspaceId).toBe(F.workspaceId);
    expect(result.worktreePath).toBe(worktreePath);

    // Manifest file written
    const manifestPath = join(stateRoot, `${manifestKey}.json`);
    expect(existsSync(manifestPath)).toBe(true);
    const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
    expect(manifest.schemaVersion).toBe(1);
    expect(manifest.prNumber).toBe(F.prNumber);
    expect(manifest.headRefOid).toBe(F.headRefOid);

    // Exactly one gh pr view call (zero — openReviewBox receives pre-fetched PrInfo)
    const ghViewCalls = calls.filter(
      (c) => c.cmd === "gh" && c.args[0] === "pr" && c.args[1] === "view"
    );
    expect(ghViewCalls).toHaveLength(0);

    // One workspace create
    const createCalls = calls.filter(
      (c) => c.cmd === "herdr" && c.args[0] === "workspace" && c.args[1] === "create"
    );
    expect(createCalls).toHaveLength(1);
  });

  test("resume path: manifest match + workspace live → focuses, action resumed", async () => {
    seedManifest(F.headRefOid);
    seedWorktree();
    const { exec, calls } = createExecStub({ workspaceGetSucceeds: true });

    const result = await openReviewBox(exec, {
      pr: prInfo,
      repoRoot,
      sharedRoot: repoRoot,
      prIdentifier: "42",
      stateRoot,
    });

    expect(result.action).toBe("resumed");
    expect(result.workspaceId).toBe(F.workspaceId);

    // No workspace create calls
    const createCalls = calls.filter(
      (c) => c.cmd === "herdr" && c.args[0] === "workspace" && c.args[1] === "create"
    );
    expect(createCalls).toHaveLength(0);

    // One focus call
    const focusCalls = calls.filter(
      (c) => c.cmd === "herdr" && c.args[0] === "workspace" && c.args[1] === "focus"
    );
    expect(focusCalls).toHaveLength(1);
  });

  test("refresh path: head changed → closes old, creates new, action refreshed", async () => {
    seedManifest("oldhead0000000000000000000000000000");
    seedWorktree();
    const { exec, calls } = createExecStub({ workspaceGetSucceeds: true });

    const result = await openReviewBox(exec, {
      pr: prInfo,
      repoRoot,
      sharedRoot: repoRoot,
      prIdentifier: "42",
      stateRoot,
    });

    expect(result.action).toBe("refreshed");

    // One workspace close + one create
    const closeCalls = calls.filter(
      (c) => c.cmd === "herdr" && c.args[0] === "workspace" && c.args[1] === "close"
    );
    expect(closeCalls).toHaveLength(1);
    const createCalls = calls.filter(
      (c) => c.cmd === "herdr" && c.args[0] === "workspace" && c.args[1] === "create"
    );
    expect(createCalls).toHaveLength(1);

    // Manifest updated with new head
    const manifest = JSON.parse(readFileSync(join(stateRoot, `${manifestKey}.json`), "utf8"));
    expect(manifest.headRefOid).toBe(F.headRefOid);
  });

  test("restore path: workspace gone + worktree exists → creates new workspace", async () => {
    seedManifest(F.headRefOid);
    seedWorktree();
    const { exec, calls } = createExecStub({ workspaceGetSucceeds: false });

    const result = await openReviewBox(exec, {
      pr: prInfo,
      repoRoot,
      sharedRoot: repoRoot,
      prIdentifier: "42",
      stateRoot,
    });

    expect(result.action).toBe("restored");

    // No workspace close (workspace was already gone)
    const closeCalls = calls.filter(
      (c) => c.cmd === "herdr" && c.args[0] === "workspace" && c.args[1] === "close"
    );
    expect(closeCalls).toHaveLength(0);

    // One workspace create
    const createCalls = calls.filter(
      (c) => c.cmd === "herdr" && c.args[0] === "workspace" && c.args[1] === "create"
    );
    expect(createCalls).toHaveLength(1);

    // No git fetch or checkout (worktree already exists and head unchanged)
    const fetchCalls = calls.filter((c) => c.cmd === "git" && c.args[0] === "fetch");
    expect(fetchCalls).toHaveLength(0);
    const checkoutCalls = calls.filter(
      (c) => c.cmd === "gh" && c.args[0] === "pr" && c.args[1] === "checkout"
    );
    expect(checkoutCalls).toHaveLength(0);
  });
});

// ─── Tests: fetchPrInfo ──────────────────────────────────────────────

describe("fetchPrInfo", () => {
  test("is exported as a function", () => {
    expect(typeof fetchPrInfo).toBe("function");
  });

  test("calls gh pr view with default fields (no state)", async () => {
    const calls: Array<{ cmd: string; args: string[] }> = [];
    const exec: ExecFn = async (cmd, args) => {
      calls.push({ cmd, args });
      if (cmd === "gh" && args[0] === "pr" && args[1] === "view")
        return {
          stdout: JSON.stringify({
            number: 42,
            title: "Test",
            baseRefName: "main",
            headRefName: "feature",
            headRefOid: "abc123",
            url: "https://github.com/o/r/pull/42",
          }),
          stderr: "",
          code: 0,
        };
      return { stdout: "", stderr: "", code: 0 };
    };

    const pr = await fetchPrInfo(exec, "42", { cwd: "/tmp/repo" });

    expect(pr.number).toBe(42);
    expect(pr.title).toBe("Test");
    expect(pr.state).toBeUndefined();

    // Exactly one gh pr view call with default fields
    expect(calls).toHaveLength(1);
    expect(calls[0].args).toContain("--json");
    const jsonIdx = calls[0].args.indexOf("--json");
    expect(calls[0].args[jsonIdx + 1]).toBe("number,title,baseRefName,headRefName,headRefOid,url");
  });

  test("calls gh pr view with state when fields include it", async () => {
    const calls: Array<{ cmd: string; args: string[] }> = [];
    const exec: ExecFn = async (cmd, args) => {
      calls.push({ cmd, args });
      if (cmd === "gh" && args[0] === "pr" && args[1] === "view")
        return {
          stdout: JSON.stringify({
            number: 42,
            title: "Test",
            baseRefName: "main",
            headRefName: "feature",
            headRefOid: "abc123",
            url: "https://github.com/o/r/pull/42",
            state: "OPEN",
          }),
          stderr: "",
          code: 0,
        };
      return { stdout: "", stderr: "", code: 0 };
    };

    const pr = await fetchPrInfo(exec, "42", {
      cwd: "/tmp/repo",
      fields: ["number", "title", "baseRefName", "headRefName", "headRefOid", "url", "state"],
      repo: "o/r",
    });

    expect(pr.state).toBe("OPEN");

    // Has --repo flag
    expect(calls[0].args).toContain("--repo");
    const repoIdx = calls[0].args.indexOf("--repo");
    expect(calls[0].args[repoIdx + 1]).toBe("o/r");

    // Fields include state
    const jsonIdx = calls[0].args.indexOf("--json");
    expect(calls[0].args[jsonIdx + 1]).toBe(
      "number,title,baseRefName,headRefName,headRefOid,url,state"
    );
  });
});

// ─── Tests: R2 per-PR lockfile ───────────────────────────────────────

describe("R2 per-PR lockfile", () => {
  test("lockfile is created and released on successful run", async () => {
    const { exec } = createExecStub({ workspaceGetSucceeds: true });

    await openReviewBox(exec, {
      pr: prInfo,
      repoRoot,
      sharedRoot: repoRoot,
      prIdentifier: "42",
      stateRoot,
    });

    // Lockfile must not remain after a clean run
    expect(existsSync(lockPath)).toBe(false);
  });

  test("stale lock (dead PID) is reclaimed without deadlock", async () => {
    // Pre-create a stale lock with a dead PID
    mkdirSync(stateRoot, { recursive: true });
    writeFileSync(lockPath, "999999");

    expect(existsSync(lockPath)).toBe(true);

    const { exec } = createExecStub({ workspaceGetSucceeds: true });

    const result = await openReviewBox(exec, {
      pr: prInfo,
      repoRoot,
      sharedRoot: repoRoot,
      prIdentifier: "42",
      stateRoot,
    });

    // Should succeed despite the stale lock
    expect(result.action).toBe("created");

    // Lockfile must be cleaned up
    expect(existsSync(lockPath)).toBe(false);
  });

  test("stale lock with non-numeric content is reclaimed", async () => {
    mkdirSync(stateRoot, { recursive: true });
    writeFileSync(lockPath, "garbage");

    const { exec } = createExecStub({ workspaceGetSucceeds: true });

    const result = await openReviewBox(exec, {
      pr: prInfo,
      repoRoot,
      sharedRoot: repoRoot,
      prIdentifier: "42",
      stateRoot,
    });

    expect(result.action).toBe("created");
    expect(existsSync(lockPath)).toBe(false);
  });
});

// ─── Tests: R4 worktree tolerance ────────────────────────────────────

describe("R4 worktree tolerance", () => {
  test("prepareReviewWorktree: existing invalid worktree is recreated", async () => {
    // Seed a directory at the canonical worktree path (not a valid git worktree)
    seedWorktree();

    const calls: Array<{ cmd: string; args: string[] }> = [];
    let checkoutAttempts = 0;
    const exec: ExecFn = async (cmd, args) => {
      calls.push({ cmd, args });
      if (cmd === "git" && args[0] === "fetch") return { stdout: "", stderr: "", code: 0 };
      if (cmd === "git" && args[0] === "worktree" && args[1] === "add") {
        mkdirSync(args[3], { recursive: true });
        return { stdout: "", stderr: "", code: 0 };
      }
      if (cmd === "git" && args[0] === "worktree" && args[1] === "prune")
        return { stdout: "", stderr: "", code: 0 };
      if (cmd === "gh" && args[0] === "pr" && args[1] === "checkout") {
        checkoutAttempts++;
        if (checkoutAttempts === 1) return { stdout: "", stderr: "not a worktree", code: 1 };
        return { stdout: "", stderr: "", code: 0 };
      }
      return { stdout: "", stderr: "", code: 0 };
    };

    const result = await prepareReviewWorktree(exec, {
      repoRoot,
      sharedRoot: repoRoot,
      prIdentifier: "42",
      prNumber: F.prNumber,
      headRefName: F.headRefName,
      baseRefName: F.baseRefName,
    });

    // Should succeed despite the existing invalid worktree
    expect(result.worktreePath).toBe(worktreePath);

    // First checkout failed, then git worktree prune, then worktree add, then checkout succeeds
    const checkoutCalls = calls.filter(
      (c) => c.cmd === "gh" && c.args[0] === "pr" && c.args[1] === "checkout"
    );
    expect(checkoutCalls).toHaveLength(2);

    const pruneCalls = calls.filter(
      (c) => c.cmd === "git" && c.args[0] === "worktree" && c.args[1] === "prune"
    );
    expect(pruneCalls).toHaveLength(1);

    const worktreeAddCalls = calls.filter(
      (c) => c.cmd === "git" && c.args[0] === "worktree" && c.args[1] === "add"
    );
    expect(worktreeAddCalls).toHaveLength(1);
  });

  test("prepareReviewWorktree: existing valid worktree is adopted (no recreate)", async () => {
    // Seed a directory at the canonical worktree path
    seedWorktree();

    const calls: Array<{ cmd: string; args: string[] }> = [];
    const exec: ExecFn = async (cmd, args) => {
      calls.push({ cmd, args });
      if (cmd === "git" && args[0] === "fetch") return { stdout: "", stderr: "", code: 0 };
      if (cmd === "git" && args[0] === "worktree" && args[1] === "add")
        return { stdout: "", stderr: "", code: 0 };
      if (cmd === "gh" && args[0] === "pr" && args[1] === "checkout")
        return { stdout: "", stderr: "", code: 0 };
      return { stdout: "", stderr: "", code: 0 };
    };

    const result = await prepareReviewWorktree(exec, {
      repoRoot,
      sharedRoot: repoRoot,
      prIdentifier: "42",
      prNumber: F.prNumber,
      headRefName: F.headRefName,
      baseRefName: F.baseRefName,
    });

    expect(result.worktreePath).toBe(worktreePath);

    // Checkout succeeds on first try — no prune, no worktree add
    const checkoutCalls = calls.filter(
      (c) => c.cmd === "gh" && c.args[0] === "pr" && c.args[1] === "checkout"
    );
    expect(checkoutCalls).toHaveLength(1);

    const pruneCalls = calls.filter(
      (c) => c.cmd === "git" && c.args[0] === "worktree" && c.args[1] === "prune"
    );
    expect(pruneCalls).toHaveLength(0);

    const worktreeAddCalls = calls.filter(
      (c) => c.cmd === "git" && c.args[0] === "worktree" && c.args[1] === "add"
    );
    expect(worktreeAddCalls).toHaveLength(0);
  });
});
