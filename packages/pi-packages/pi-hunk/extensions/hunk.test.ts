import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, test } from "bun:test";
import hunkExtension from "./hunk.js";

type RegisteredTool = {
  execute: (_id: string, params: Record<string, any>) => Promise<unknown>;
};

function createPiMock(hunkStdout?: string) {
  const calls: Array<{ command: string; args: string[]; options: Record<string, unknown> }> = [];
  const tools: Record<string, RegisteredTool> = {};
  const pi = {
    registerTool(tool: RegisteredTool & { name: string }) {
      tools[tool.name] = tool;
    },
    async exec(command: string, args: string[], options: Record<string, unknown> = {}) {
      calls.push({ command, args, options });
      if (command === "git" && args.join(" ") === "rev-parse --git-path hunk/last-pi-turn.json") {
        return { code: 0, stdout: ".git/hunk/last-pi-turn.json\n", stderr: "" };
      }
      if (command === "git" && args.join(" ") === "rev-parse --git-path hunk/last-pi-turn.patch") {
        return { code: 0, stdout: ".git/hunk/last-pi-turn.patch\n", stderr: "" };
      }
      if (command === "git" && args[0] === "diff") {
        return { code: 0, stdout: "diff --git a/file.txt b/file.txt", stderr: "" };
      }
      if (command === "herdr" && args[0] === "pane" && args[1] === "split") {
        return {
          code: 0,
          stdout: JSON.stringify({
            result: {
              root_pane: { pane_id: 42 },
              pane: { pane_id: "pane-hunk" },
            },
          }),
          stderr: "",
        };
      }
      if (command === "herdr" && args[0] === "tab" && args[1] === "create") {
        return {
          code: 0,
          stdout: JSON.stringify({
            result: {
              root_pane: { pane_id: "tab-hunk" },
              pane: { pane_id: 42 },
            },
          }),
          stderr: "",
        };
      }
      if (command === "hunk" && hunkStdout !== undefined) {
        return { code: 0, stdout: hunkStdout, stderr: "" };
      }
      return { code: 0, stdout: `${command} ${args.join(" ")}`, stderr: "" };
    },
  };

  hunkExtension(pi as any);
  return { calls, tools };
}

describe("pi-hunk", () => {
  test("hunk_commit stages, commits, then pushes after successful commit", async () => {
    const { calls, tools } = createPiMock();

    await tools.hunk_commit!.execute("1", {
      repo: "/repo",
      message: "feat: source switch",
      includeUnstaged: true,
      push: true,
    });

    expect(calls.map((call) => [call.command, call.args])).toEqual([
      ["git", ["add", "-A"]],
      ["git", ["commit", "-m", "feat: source switch"]],
      ["git", ["push"]],
    ]);
  });

  test("hunk_commit rejects blank messages before git commands", async () => {
    const { calls, tools } = createPiMock();

    await expect(tools.hunk_commit!.execute("1", { repo: "/repo", message: "  " })).rejects.toThrow(
      "message is required"
    );
    expect(calls).toEqual([]);
  });

  test("hunk_diff writes Last Pi turn marker for Hunk source switching", async () => {
    const repo = mkdtempSync(join(tmpdir(), "pi-hunk-marker-"));
    const { calls, tools } = createPiMock();
    const previousWorkspace = process.env.HERDR_WORKSPACE_ID;
    const previousPane = process.env.HERDR_PANE_ID;
    process.env.HERDR_WORKSPACE_ID = "workspace-1";
    process.env.HERDR_PANE_ID = "pane-pi";

    try {
      await tools.hunk_diff!.execute("1", {
        repo,
        target: "origin/main",
        staged: true,
        pathspecs: ["src"],
      });

      expect(calls.map((call) => call.command)).toEqual([
        "git",
        "git",
        "git",
        "herdr",
        "herdr",
        "herdr",
      ]);
      expect(calls[2]!.args).toEqual(["diff", "--staged", "origin/main", "--", "src"]);
      expect(calls[3]!.args).toEqual([
        "pane",
        "split",
        "pane-pi",
        "--direction",
        "right",
        "--cwd",
        repo,
        "--focus",
      ]);
      expect(calls[4]!.args).toEqual(["pane", "rename", "pane-hunk", "hunk"]);
      expect(calls[5]!.args.slice(0, 2)).toEqual(["pane", "run"]);
      expect(calls[5]!.args[2]).toBe("pane-hunk");
      expect(calls[5]!.args[3]).toContain("hunk 'diff' '--staged' 'origin/main' '--' 'src'");
      const marker = JSON.parse(readFileSync(join(repo, ".git/hunk/last-pi-turn.json"), "utf8"));
      expect(marker).toMatchObject({
        version: 1,
        source: "pi-hunk",
        kind: "patch",
        file: join(repo, ".git/hunk/last-pi-turn.patch"),
        range: "origin/main",
        staged: true,
        pathspecs: ["src"],
      });
      expect(readFileSync(join(repo, ".git/hunk/last-pi-turn.patch"), "utf8")).toContain(
        "diff --git"
      );
    } finally {
      if (previousWorkspace === undefined) delete process.env.HERDR_WORKSPACE_ID;
      else process.env.HERDR_WORKSPACE_ID = previousWorkspace;
      if (previousPane === undefined) delete process.env.HERDR_PANE_ID;
      else process.env.HERDR_PANE_ID = previousPane;
      rmSync(repo, { force: true, recursive: true });
    }
  });

  test("hunk_diff reads workspace and pane ids from validated Herdr context", async () => {
    const repo = mkdtempSync(join(tmpdir(), "pi-hunk-context-"));
    const { calls, tools } = createPiMock();
    const previousWorkspace = process.env.HERDR_WORKSPACE_ID;
    const previousPane = process.env.HERDR_PANE_ID;
    const previousContext = process.env.HERDR_PLUGIN_CONTEXT_JSON;
    delete process.env.HERDR_WORKSPACE_ID;
    delete process.env.HERDR_PANE_ID;
    process.env.HERDR_PLUGIN_CONTEXT_JSON = JSON.stringify({
      workspace_id: "workspace-context",
      focused_pane_id: "pane-context",
    });

    try {
      await tools.hunk_diff!.execute("1", { repo });

      expect(calls[3]!.args).toEqual([
        "pane",
        "split",
        "pane-context",
        "--direction",
        "right",
        "--cwd",
        repo,
        "--focus",
      ]);
    } finally {
      if (previousWorkspace === undefined) delete process.env.HERDR_WORKSPACE_ID;
      else process.env.HERDR_WORKSPACE_ID = previousWorkspace;
      if (previousPane === undefined) delete process.env.HERDR_PANE_ID;
      else process.env.HERDR_PANE_ID = previousPane;
      if (previousContext === undefined) delete process.env.HERDR_PLUGIN_CONTEXT_JSON;
      else process.env.HERDR_PLUGIN_CONTEXT_JSON = previousContext;
      rmSync(repo, { force: true, recursive: true });
    }
  });

  test("hunk_diff rejects a non-string workspace id from Herdr context", async () => {
    const repo = mkdtempSync(join(tmpdir(), "pi-hunk-invalid-context-"));
    const { calls, tools } = createPiMock();
    const previousWorkspace = process.env.HERDR_WORKSPACE_ID;
    const previousContext = process.env.HERDR_PLUGIN_CONTEXT_JSON;
    delete process.env.HERDR_WORKSPACE_ID;
    process.env.HERDR_PLUGIN_CONTEXT_JSON = JSON.stringify({ workspace_id: 42 });

    try {
      await expect(tools.hunk_diff!.execute("1", { repo })).rejects.toThrow(
        "hunk_diff must run inside a Herdr workspace"
      );
      expect(calls.some((call) => call.command === "herdr")).toBe(false);
    } finally {
      if (previousWorkspace === undefined) delete process.env.HERDR_WORKSPACE_ID;
      else process.env.HERDR_WORKSPACE_ID = previousWorkspace;
      if (previousContext === undefined) delete process.env.HERDR_PLUGIN_CONTEXT_JSON;
      else process.env.HERDR_PLUGIN_CONTEXT_JSON = previousContext;
      rmSync(repo, { force: true, recursive: true });
    }
  });

  test("hunk_diff accepts a valid requested field when its context sibling is malformed", async () => {
    const repo = mkdtempSync(join(tmpdir(), "pi-hunk-context-sibling-"));
    const { calls, tools } = createPiMock();
    const previousWorkspace = process.env.HERDR_WORKSPACE_ID;
    const previousContext = process.env.HERDR_PLUGIN_CONTEXT_JSON;
    delete process.env.HERDR_WORKSPACE_ID;
    process.env.HERDR_PLUGIN_CONTEXT_JSON = JSON.stringify({
      workspace_id: "workspace-context",
      focused_pane_id: 42,
    });

    try {
      await tools.hunk_diff!.execute("1", { repo, placement: "tab" });

      expect(calls[3]!.args).toEqual([
        "tab",
        "create",
        "--workspace",
        "workspace-context",
        "--cwd",
        repo,
        "--label",
        "hunk",
      ]);
      expect(calls[4]!.args).toEqual(["pane", "rename", "tab-hunk", "hunk"]);
    } finally {
      if (previousWorkspace === undefined) delete process.env.HERDR_WORKSPACE_ID;
      else process.env.HERDR_WORKSPACE_ID = previousWorkspace;
      if (previousContext === undefined) delete process.env.HERDR_PLUGIN_CONTEXT_JSON;
      else process.env.HERDR_PLUGIN_CONTEXT_JSON = previousContext;
      rmSync(repo, { force: true, recursive: true });
    }
  });

  test("hunk_review preserves parsed details and JSON string output", async () => {
    const { tools } = createPiMock('"review-ready"');

    const result = await tools.hunk_review!.execute("1", { repo: "/repo" });

    expect(result).toMatchObject({
      content: [{ type: "text", text: "review-ready" }],
      details: { parsed: "review-ready", stdout: '"review-ready"' },
    });
  });

  test("hunk_review preserves empty output as parsed null", async () => {
    const { tools } = createPiMock("");

    const result = await tools.hunk_review!.execute("1", { repo: "/repo" });

    expect(result).toMatchObject({
      content: [{ type: "text", text: "null" }],
      details: { parsed: null, stdout: "" },
    });
  });
});
