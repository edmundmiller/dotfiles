import { describe, expect, test, beforeEach, afterEach } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

/**
 * Golden recording-exec tests for the resume, refresh, and restore decision
 * paths — extending the create-path golden test in pr-review-workspace.test.ts.
 *
 * Each path invokes the herdr_pr_review_workspace tool's execute() with a
 * recording exec stub against a fixed PR fixture + seeded manifest/worktree
 * fixtures. The exec call sequence (cmd/args/cwd/timeout) is diffed against a
 * golden capture from the pre-extraction implementation.
 *
 * Golden files are generated on first run. On subsequent runs the recorded
 * sequence must match the golden exactly, proving behavior equivalence across
 * the extraction.
 */

type RecordedCall = {
  cmd: string;
  args: string[];
  cwd: string | undefined;
  timeout: number | undefined;
};

// ─── Fixed PR fixture ────────────────────────────────────────────────

const F = {
  prIdentifier: "42",
  prNumber: 42,
  prTitle: "Fix all the bugs",
  prUrl: "https://github.com/acme/widget/pull/42",
  baseRefName: "main",
  headRefName: "feature-branch",
  headRefOid: "abc123def456789012345678901234567890abcd",
  workspaceId: "wABC",
} as const;

// ─── Manifest key (must match manifestKeyFor in the shared module) ────

const manifestKey = "acme-widget-pr-42";
const worktreeSlug = "pr-42-feature-branch";

// ─── Test-scoped state ───────────────────────────────────────────────

let tempDir: string;
let repoRoot: string;
let stateRoot: string;
let worktreePath: string;
let oldXdgStateHome: string | undefined;

beforeEach(() => {
  tempDir = mkdtempSync(join(tmpdir(), "pi-herdr-flow-"));
  repoRoot = join(tempDir, "widget");
  stateRoot = join(tempDir, "state", "pi-herdr", "review-boxes");
  worktreePath = join(repoRoot, ".pi", "worktrees", worktreeSlug);
  mkdirSync(join(repoRoot, ".git"), { recursive: true });
  oldXdgStateHome = process.env.XDG_STATE_HOME;
  process.env.XDG_STATE_HOME = join(tempDir, "state");
});

afterEach(() => {
  if (oldXdgStateHome === undefined) delete process.env.XDG_STATE_HOME;
  else process.env.XDG_STATE_HOME = oldXdgStateHome;
  rmSync(tempDir, { recursive: true, force: true });
});

// ─── Recording exec stub with canned responses ───────────────────────

function createRecordingExec(opts: { workspaceGetSucceeds: boolean }) {
  const calls: RecordedCall[] = [];
  const realCwd = process.cwd();
  let tabCounter = 0;

  const normStr = (s: string): string =>
    tempDir && s.includes(tempDir) ? s.split(tempDir).join("<TEMP>") : s;

  const normCwd = (cwd: string | undefined): string | undefined => {
    if (cwd === undefined) return undefined;
    if (cwd === realCwd) return "<CWD>";
    return normStr(cwd);
  };

  const exec = async (
    command: string,
    args: string[],
    options?: { cwd?: string; timeout?: number }
  ): Promise<{ stdout: string; stderr: string; code: number; killed: boolean }> => {
    calls.push({
      cmd: command,
      args: args.map(normStr),
      cwd: normCwd(options?.cwd),
      timeout: options?.timeout,
    });
    return { ...respond(command, args, opts, () => ++tabCounter), killed: false };
  };

  return { exec, calls };
}

function respond(
  cmd: string,
  args: string[],
  opts: { workspaceGetSucceeds: boolean },
  nextTab: () => number
): { stdout: string; stderr: string; code: number } {
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
  if (cmd === "git" && args[0] === "worktree" && args[1] === "add")
    return { stdout: "", stderr: "", code: 0 };
  if (cmd === "gh" && args[0] === "pr" && args[1] === "checkout")
    return { stdout: "", stderr: "", code: 0 };
  if (cmd === "herdr" && args[0] === "workspace" && args[1] === "create")
    return {
      stdout: JSON.stringify({
        id: "cli:workspace:create",
        result: { workspace_id: F.workspaceId },
      }),
      stderr: "",
      code: 0,
    };
  if (cmd === "herdr" && args[0] === "workspace" && args[1] === "get") {
    if (opts.workspaceGetSucceeds)
      return {
        stdout: JSON.stringify({
          id: "cli:workspace:get",
          result: { workspace_id: F.workspaceId },
        }),
        stderr: "",
        code: 0,
      };
    return { stdout: "", stderr: "workspace not found", code: 1 };
  }
  if (cmd === "herdr" && args[0] === "workspace" && args[1] === "close")
    return { stdout: "", stderr: "", code: 0 };
  if (cmd === "herdr" && args[0] === "tab" && args[1] === "create")
    return {
      stdout: JSON.stringify({
        id: "cli:tab:create",
        result: { pane_id: `${F.workspaceId}-${nextTab()}` },
      }),
      stderr: "",
      code: 0,
    };
  if (cmd === "herdr" && args[0] === "pane") return { stdout: "", stderr: "", code: 0 };
  if (cmd === "herdr" && args[0] === "workspace" && args[1] === "focus")
    return { stdout: "", stderr: "", code: 0 };
  if (cmd === "git" && args[0] === "rev-parse" && args[1] === "HEAD")
    return { stdout: `${F.headRefOid}\n`, stderr: "", code: 0 };
  return { stdout: "", stderr: "", code: 0 };
}

// ─── Mock ExtensionAPI ───────────────────────────────────────────────

async function loadExtension(recordingExec: ReturnType<typeof createRecordingExec>) {
  const tools: Record<string, { name: string; execute: Function }> = {};
  const api = {
    exec: recordingExec.exec,
    registerTool: (tool: { name: string; execute: Function }) => {
      tools[tool.name] = tool;
    },
    registerCommand: () => {},
    on: () => {},
  } as unknown as Parameters<typeof import("./herdr.js").default>[0];

  const mod = await import("./herdr.js");
  mod.default(api);
  return tools;
}

// ─── Helpers ─────────────────────────────────────────────────────────

function seedManifest(headRefOid: string): void {
  mkdirSync(stateRoot, { recursive: true });
  const manifest = {
    schemaVersion: 1,
    repoRoot: repoRoot,
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

function goldenPath(name: string): string {
  return join(import.meta.dir, `golden-${name}.json`);
}

// ─── Tests ───────────────────────────────────────────────────────────

describe("decision-flow golden equivalence", () => {
  test("resume path exec sequence matches golden capture", async () => {
    seedManifest(F.headRefOid); // head unchanged
    seedWorktree();

    const recording = createRecordingExec({ workspaceGetSucceeds: true });
    const tools = await loadExtension(recording);

    const tool = tools["herdr_pr_review_workspace"];
    expect(tool).toBeDefined();

    await tool.execute("test-call-id", { pr: F.prIdentifier }, undefined, undefined, {
      cwd: repoRoot,
    });

    const golden = goldenPath("resume");
    if (!existsSync(golden)) {
      writeFileSync(golden, JSON.stringify(recording.calls, null, 2) + "\n");
      console.log(`Golden capture written to ${golden}`);
      expect(recording.calls.length).toBeGreaterThan(3);
    } else {
      const expected: RecordedCall[] = JSON.parse(readFileSync(golden, "utf-8"));
      expect(recording.calls).toEqual(expected);
    }
  });

  test("refresh path exec sequence matches golden capture", async () => {
    seedManifest("oldhead0000000000000000000000000000"); // head changed
    seedWorktree();

    const recording = createRecordingExec({ workspaceGetSucceeds: true });
    const tools = await loadExtension(recording);

    const tool = tools["herdr_pr_review_workspace"];
    expect(tool).toBeDefined();

    await tool.execute("test-call-id", { pr: F.prIdentifier }, undefined, undefined, {
      cwd: repoRoot,
    });

    const golden = goldenPath("refresh");
    if (!existsSync(golden)) {
      writeFileSync(golden, JSON.stringify(recording.calls, null, 2) + "\n");
      console.log(`Golden capture written to ${golden}`);
      expect(recording.calls.length).toBeGreaterThan(10);
    } else {
      const expected: RecordedCall[] = JSON.parse(readFileSync(golden, "utf-8"));
      expect(recording.calls).toEqual(expected);
    }
  });

  test("restore path exec sequence matches golden capture", async () => {
    seedManifest(F.headRefOid); // head unchanged
    seedWorktree();

    const recording = createRecordingExec({ workspaceGetSucceeds: false });
    const tools = await loadExtension(recording);

    const tool = tools["herdr_pr_review_workspace"];
    expect(tool).toBeDefined();

    await tool.execute("test-call-id", { pr: F.prIdentifier }, undefined, undefined, {
      cwd: repoRoot,
    });

    const golden = goldenPath("restore");
    if (!existsSync(golden)) {
      writeFileSync(golden, JSON.stringify(recording.calls, null, 2) + "\n");
      console.log(`Golden capture written to ${golden}`);
      expect(recording.calls.length).toBeGreaterThan(10);
    } else {
      const expected: RecordedCall[] = JSON.parse(readFileSync(golden, "utf-8"));
      expect(recording.calls).toEqual(expected);
    }
  });
});
