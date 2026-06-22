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

  test("hunk_diff writes Last Pi turn marker for Hunk source switching", async () => {
    const repo = mkdtempSync(join(tmpdir(), "pi-hunk-marker-"));
    const { calls, tools } = createPiMock();

    try {
      await tools.hunk_diff!.execute("1", {
        repo,
        target: "origin/main",
        staged: true,
        pathspecs: ["src"],
      });

      expect(calls.map((call) => call.command)).toEqual(["herdr-hunk", "git"]);
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
      rmSync(repo, { force: true, recursive: true });
    }
  });
});
