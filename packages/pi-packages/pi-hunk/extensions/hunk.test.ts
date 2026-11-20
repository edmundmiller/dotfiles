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

  test("hunk_reload preserves Last Pi turn source switching without the retired pane tool", async () => {
    const repo = mkdtempSync(join(tmpdir(), "pi-hunk-marker-"));
    const { calls, tools } = createPiMock();

    try {
      expect(tools.hunk_diff).toBeUndefined();
      await tools.hunk_reload!.execute("1", {
        repo,
        target: "origin/main",
        pathspecs: ["src"],
      });

      expect(calls.map((call) => call.command)).toEqual(["hunk", "git", "git", "git"]);
      expect(calls[0]!.args).toEqual([
        "session",
        "reload",
        "--repo",
        repo,
        "--",
        "diff",
        "origin/main",
        "--",
        "src",
      ]);
      expect(calls[3]!.args).toEqual(["diff", "origin/main", "--", "src"]);
      const marker = JSON.parse(readFileSync(join(repo, ".git/hunk/last-pi-turn.json"), "utf8"));
      expect(marker).toMatchObject({
        version: 1,
        source: "pi-hunk",
        kind: "patch",
        file: join(repo, ".git/hunk/last-pi-turn.patch"),
        range: "origin/main",
        staged: false,
        pathspecs: ["src"],
      });
      expect(readFileSync(join(repo, ".git/hunk/last-pi-turn.patch"), "utf8")).toContain(
        "diff --git"
      );
    } finally {
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
