import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, test } from "bun:test";
import hunkExtension from "./hunk.js";

type RegisteredTool = {
  execute: (_id: string, params: Record<string, any>) => Promise<unknown>;
};

function createPiMock() {
  const calls: Array<{ command: string; args: string[]; options: Record<string, unknown> }> = [];
  const tools: Record<string, RegisteredTool> = {};
  const pi = {
    registerTool(tool: RegisteredTool & { name: string }) {
      tools[tool.name] = tool;
    },
    async exec(command: string, args: string[], options: Record<string, unknown> = {}) {
      calls.push({ command, args, options });
      if (command === "herdr" && args[0] === "pane" && args[1] === "split") {
        return {
          code: 0,
          stdout: JSON.stringify({ result: { pane: { pane_id: "w1:p9" } } }),
          stderr: "",
        };
      }
      if (command === "git" && args.join(" ") === "rev-parse --git-path hunk/last-pi-turn.json") {
        return { code: 0, stdout: ".git/hunk/last-pi-turn.json\n", stderr: "" };
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

  test.failing("hunk_diff uses the supported Herdr pane API after helper removal", async () => {
    const repo = mkdtempSync(join(tmpdir(), "pi-hunk-marker-"));
    const { calls, tools } = createPiMock();
    const previousEnv = {
      HERDR_ENV: process.env.HERDR_ENV,
      HERDR_PANE_ID: process.env.HERDR_PANE_ID,
      HERDR_WORKSPACE_ID: process.env.HERDR_WORKSPACE_ID,
    };
    process.env.HERDR_ENV = "1";
    process.env.HERDR_PANE_ID = "w1:p1";
    process.env.HERDR_WORKSPACE_ID = "w1";

    try {
      await tools.hunk_diff!.execute("1", {
        repo,
        target: "origin/main",
        staged: true,
        pathspecs: ["src"],
      });

      expect(calls.map((call) => call.command)).toEqual(["herdr", "herdr", "herdr", "git"]);
      expect(calls[0]!.args).toEqual([
        "pane",
        "split",
        "w1:p1",
        "--direction",
        "right",
        "--cwd",
        repo,
        "--focus",
      ]);
      expect(calls[1]!.args).toEqual(["pane", "rename", "w1:p9", "hunk"]);
      expect(calls[2]!.args[0]).toBe("pane");
      expect(calls[2]!.args[1]).toBe("run");
      expect(calls[2]!.args[2]).toBe("w1:p9");
      expect(calls[2]!.args[3]).toContain("hunk diff --staged --watch origin/main -- src");
      const marker = JSON.parse(readFileSync(join(repo, ".git/hunk/last-pi-turn.json"), "utf8"));
      expect(marker).toMatchObject({
        version: 1,
        source: "pi-hunk",
        kind: "vcs",
        range: "origin/main",
        staged: true,
        pathspecs: ["src"],
      });
    } finally {
      for (const [key, value] of Object.entries(previousEnv)) {
        if (value === undefined) delete process.env[key];
        else process.env[key] = value;
      }
      rmSync(repo, { force: true, recursive: true });
    }
  });
});
