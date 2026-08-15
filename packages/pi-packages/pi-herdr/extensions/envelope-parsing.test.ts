import { describe, expect, test, beforeEach, afterEach } from "bun:test";
import { mkdirSync, mkdtempSync, rmSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";

/**
 * Regression tests for herdr CLI envelope-aware response parsing.
 *
 * The real herdr CLI wraps responses in an envelope:
 *   {"id":"cli:workspace:create","result":{"workspace_id":"w41",...}}
 *
 * The top-level envelope "id" ("cli:workspace:create") must NOT be
 * extracted as the workspace id — findStringKey must prefer keys inside
 * the "result" object when the envelope shape is present, while keeping
 * flat (non-envelope) responses working for backward compat.
 */

import {
  findStringKey,
  createHerdrReviewWorkspace,
  openReviewBox,
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
  workspaceId: "w41",
} as const;

const prInfo: PrInfo = {
  number: F.prNumber,
  title: F.prTitle,
  baseRefName: F.baseRefName,
  headRefName: F.headRefName,
  headRefOid: F.headRefOid,
  url: F.prUrl,
};

// ─── Test-scoped state ───────────────────────────────────────────────

let tempDir: string;
let repoRoot: string;
let stateRoot: string;
let worktreePath: string;
let oldXdgStateHome: string | undefined;

beforeEach(() => {
  tempDir = mkdtempSync(join(tmpdir(), "pi-herdr-envelope-"));
  repoRoot = join(tempDir, "widget");
  stateRoot = join(tempDir, "state", "pi-herdr", "review-boxes");
  worktreePath = join(repoRoot, ".pi", "worktrees", "pr-42-feature-branch");
  mkdirSync(join(repoRoot, ".git"), { recursive: true });
  oldXdgStateHome = process.env.XDG_STATE_HOME;
  process.env.XDG_STATE_HOME = join(tempDir, "state");
});

afterEach(() => {
  if (oldXdgStateHome === undefined) delete process.env.XDG_STATE_HOME;
  else process.env.XDG_STATE_HOME = oldXdgStateHome;
  rmSync(tempDir, { recursive: true, force: true });
});

// ─── Envelope helper ─────────────────────────────────────────────────

/** Wrap a payload in the real herdr CLI envelope shape. */
const envelope = (id: string, result: Record<string, unknown>): string =>
  JSON.stringify({ id, result });

// ─── Tests: findStringKey envelope awareness ─────────────────────────

describe("findStringKey envelope awareness", () => {
  test("envelope response: prefers result.workspace_id over envelope id", () => {
    const response = JSON.parse(envelope("cli:workspace:create", { workspace_id: "w41" }));
    expect(findStringKey(response, new Set(["workspace_id", "id"]))).toBe("w41");
  });

  test("envelope response: does NOT return the envelope id as the workspace id", () => {
    const response = JSON.parse(envelope("cli:workspace:create", { workspace_id: "w41" }));
    const result = findStringKey(response, new Set(["workspace_id", "id"]));
    expect(result).not.toBe("cli:workspace:create");
  });

  test("envelope response for tab create: extracts result.pane_id", () => {
    const response = JSON.parse(envelope("cli:tab:create", { pane_id: "w41-1" }));
    expect(findStringKey(response, new Set(["pane_id"]))).toBe("w41-1");
  });

  test("flat response with workspace_id: still works (backward compat)", () => {
    const response = { workspace_id: "w41" };
    expect(findStringKey(response, new Set(["workspace_id", "id"]))).toBe("w41");
  });

  test("flat response with id only (no result): still works (backward compat)", () => {
    const response = { id: "w41" };
    expect(findStringKey(response, new Set(["workspace_id", "id"]))).toBe("w41");
  });

  test("nested non-envelope response: still works (backward compat)", () => {
    const response = { result: { workspace: { workspace_id: "2" } } };
    expect(findStringKey(response, new Set(["pane_id", "workspace_id"]))).toBe("2");
  });
});

// ─── Tests: createHerdrReviewWorkspace with envelope responses ───────

describe("createHerdrReviewWorkspace envelope regression", () => {
  test("closes the initial workspace tab after creating Hunk", async () => {
    let tabCounter = 0;
    const calls: string[][] = [];
    const initialTabId = `${F.workspaceId}:t1`;
    const exec: ExecFn = async (cmd, args) => {
      calls.push([cmd, ...args]);
      if (cmd === "herdr" && args[0] === "workspace" && args[1] === "create")
        return {
          stdout: envelope("cli:workspace:create", {
            workspace_id: F.workspaceId,
            tab_id: initialTabId,
          }),
          stderr: "",
          code: 0,
        };
      if (cmd === "herdr" && args[0] === "tab" && args[1] === "create") {
        tabCounter++;
        return {
          stdout: envelope("cli:tab:create", { pane_id: `${F.workspaceId}-${tabCounter}` }),
          stderr: "",
          code: 0,
        };
      }
      return { stdout: "", stderr: "", code: 0 };
    };

    const result = await createHerdrReviewWorkspace(exec, {
      worktreePath,
      prNumber: F.prNumber,
      title: F.prTitle,
      prUrl: F.prUrl,
      diffTarget: "origin/main...HEAD",
      diffBase: "origin/main",
    });

    expect(result.workspaceId).toBe(F.workspaceId);
    const hunkCreateIndex = calls.findIndex(
      (call) => call[1] === "tab" && call[2] === "create" && call.includes("Hunk")
    );
    const initialCloseIndex = calls.findIndex(
      (call) => call[1] === "tab" && call[2] === "close" && call[3] === initialTabId
    );
    expect(hunkCreateIndex).toBeGreaterThanOrEqual(0);
    expect(initialCloseIndex).toBeGreaterThan(hunkCreateIndex);
  });
});

// ─── Tests: openReviewBox resume path with envelope responses ────────

describe("openReviewBox resume path with envelope responses", () => {
  test("resume: envelope-shaped workspace get detects live workspace and resumes", async () => {
    // Seed a manifest and worktree
    mkdirSync(stateRoot, { recursive: true });
    mkdirSync(worktreePath, { recursive: true });
    const manifest = {
      schemaVersion: 1,
      repoRoot,
      prNumber: F.prNumber,
      prUrl: F.prUrl,
      headRefOid: F.headRefOid,
      worktreePath,
      workspaceId: F.workspaceId,
      diffTarget: "origin/main...HEAD",
      agent: "omp",
      updatedAt: "2025-01-01T00:00:00.000Z",
    };
    const { writeFileSync } = await import("node:fs");
    writeFileSync(
      join(stateRoot, "acme-widget-pr-42.json"),
      JSON.stringify(manifest, null, 2) + "\n"
    );

    const calls: Array<{ cmd: string; args: string[] }> = [];
    const exec: ExecFn = async (cmd, args) => {
      calls.push({ cmd, args });
      if (cmd === "herdr" && args[0] === "workspace" && args[1] === "get")
        return {
          stdout: envelope("cli:workspace:get", { workspace_id: F.workspaceId }),
          stderr: "",
          code: 0,
        };
      if (cmd === "herdr" && args[0] === "workspace" && args[1] === "focus")
        return { stdout: "", stderr: "", code: 0 };
      return { stdout: "", stderr: "", code: 0 };
    };

    const result = await openReviewBox(exec, {
      pr: prInfo,
      repoRoot,
      sharedRoot: repoRoot,
      prIdentifier: "42",
      stateRoot,
    });

    expect(result.action).toBe("resumed");
    expect(result.workspaceId).toBe(F.workspaceId);
  });
});
