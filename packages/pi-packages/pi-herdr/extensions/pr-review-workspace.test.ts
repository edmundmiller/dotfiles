import { describe, expect, test, beforeEach, afterEach } from "bun:test";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

/**
 * Golden equivalence test for the PR-review workspace orchestration.
 *
 * Invokes the herdr_pr_review_workspace tool's execute() with a recording
 * exec stub against a fixed PR fixture. Captures the full exec call sequence
 * (cmd/args/cwd/timeout) and diffs it against a golden capture taken from
 * the pre-extraction implementation on origin/main.
 *
 * The golden file (golden-exec-sequence.json) is generated on first run.
 * On subsequent runs the recorded sequence must match the golden exactly,
 * proving behavior equivalence before and after the extraction.
 */

type RecordedCall = {
  cmd: string;
  args: string[];
  cwd: string | undefined;
  timeout: number | undefined;
};

const GOLDEN_PATH = join(import.meta.dir, "golden-exec-sequence.json");

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

// ─── Test-scoped state ───────────────────────────────────────────────

let tempDir: string;
let repoRoot: string;
let oldXdgStateHome: string | undefined;

beforeEach(() => {
  tempDir = mkdtempSync(join(tmpdir(), "pi-herdr-golden-"));
  repoRoot = join(tempDir, "widget");
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

function createRecordingExec() {
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
    return { ...respond(command, args, () => ++tabCounter), killed: false };
  };

  return { exec, calls };
}

function respond(
  cmd: string,
  args: string[],
  nextTab: () => number
): { stdout: string; stderr: string; code: number } {
  // git rev-parse --show-toplevel
  if (cmd === "git" && args[0] === "rev-parse" && args[1] === "--show-toplevel")
    return { stdout: `${repoRoot}\n`, stderr: "", code: 0 };
  // git rev-parse --path-format=absolute --git-common-dir
  if (cmd === "git" && args[0] === "rev-parse" && args.includes("--git-common-dir"))
    return { stdout: `${join(repoRoot, ".git")}\n`, stderr: "", code: 0 };
  // gh pr view <pr> --json ...
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
  // git fetch origin <base>
  if (cmd === "git" && args[0] === "fetch") return { stdout: "", stderr: "", code: 0 };
  // git worktree add --detach <path> <base>
  if (cmd === "git" && args[0] === "worktree" && args[1] === "add")
    return { stdout: "", stderr: "", code: 0 };
  // gh pr checkout <pr> --detach --force
  if (cmd === "gh" && args[0] === "pr" && args[1] === "checkout")
    return { stdout: "", stderr: "", code: 0 };
  // herdr workspace create --cwd ... --label ... --env ... --focus
  if (cmd === "herdr" && args[0] === "workspace" && args[1] === "create")
    return { stdout: JSON.stringify({ workspace_id: F.workspaceId }), stderr: "", code: 0 };
  // herdr workspace get (for workspaceExists — returns success)
  if (cmd === "herdr" && args[0] === "workspace" && args[1] === "get")
    return { stdout: JSON.stringify({ workspace_id: F.workspaceId }), stderr: "", code: 0 };
  // herdr tab create --workspace ... --cwd ... --label ... --no-focus
  if (cmd === "herdr" && args[0] === "tab" && args[1] === "create")
    return {
      stdout: JSON.stringify({ pane_id: `${F.workspaceId}-${nextTab()}` }),
      stderr: "",
      code: 0,
    };
  // herdr pane rename / pane run
  if (cmd === "herdr" && args[0] === "pane") return { stdout: "", stderr: "", code: 0 };
  // herdr workspace focus
  if (cmd === "herdr" && args[0] === "workspace" && args[1] === "focus")
    return { stdout: "", stderr: "", code: 0 };
  // git rev-parse HEAD
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

// ─── Tests ───────────────────────────────────────────────────────────

describe("pr-review-workspace golden equivalence", () => {
  test("exec call sequence matches golden capture", async () => {
    const recording = createRecordingExec();
    const tools = await loadExtension(recording);

    const tool = tools["herdr_pr_review_workspace"];
    expect(tool).toBeDefined();

    await tool.execute("test-call-id", { pr: F.prIdentifier }, undefined, undefined, {
      cwd: repoRoot,
    });

    if (!existsSync(GOLDEN_PATH)) {
      writeFileSync(GOLDEN_PATH, JSON.stringify(recording.calls, null, 2) + "\n");
      console.log(`Golden capture written to ${GOLDEN_PATH}`);
      expect(recording.calls.length).toBeGreaterThan(10);
    } else {
      const golden: RecordedCall[] = JSON.parse(readFileSync(GOLDEN_PATH, "utf-8"));
      expect(recording.calls).toEqual(golden);
    }
  });

  test("prepareReviewWorktree, refreshReviewWorktree, createHerdrReviewWorkspace are exported", async () => {
    const mod = await import("./pr-review-workspace.js");
    expect(typeof mod.prepareReviewWorktree).toBe("function");
    expect(typeof mod.refreshReviewWorktree).toBe("function");
    expect(typeof mod.createHerdrReviewWorkspace).toBe("function");
  });

  test("pr-review-workspace module has no @mariozechner/pi-coding-agent import", async () => {
    const source = readFileSync(join(import.meta.dir, "pr-review-workspace.ts"), "utf-8");
    expect(source).not.toContain("@mariozechner/pi-coding-agent");
  });
});
