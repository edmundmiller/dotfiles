import { describe, expect, test } from "bun:test";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { mkdtemp, mkdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  buildApprovalCommand,
  buildReviewPrompt,
  findStringKey,
  openPrReviewWorkspace,
  slugify,
} from "./herdr.js";

describe("pi-herdr review workspace helpers", () => {
  test("slugify makes branch/path safe PR slugs", () => {
    expect(slugify("PR #123: Fix Hunk + OMP review!")).toBe("pr-123-fix-hunk-omp-review");
  });

  test("findStringKey extracts nested Herdr ids", () => {
    expect(
      findStringKey(
        {
          result: {
            workspace: { workspace_id: "2" },
            root_pane: { pane_id: "2-1" },
          },
        },
        new Set(["pane_id"])
      )
    ).toBe("2-1");
  });

  test("review prompt tells OMP to use Hunk comments", () => {
    const prompt = buildReviewPrompt({
      pr: {
        number: 42,
        title: "Review workflow",
        baseRefName: "main",
        headRefName: "feature",
        headRefOid: "abc123",
        url: "https://github.com/o/r/pull/42",
      },
      repo: "/tmp/repo-pr-42",
      diffTarget: "origin/main...HEAD",
      hunkTab: "Hunk",
    });

    expect(prompt).toContain("/review");
    expect(prompt).toContain("Hunk");
    expect(prompt).toContain("hunk_comments action=apply");
    expect(prompt).toContain("approve/request-changes recommendation");
  });

  test("approval command is manual and contains both review outcomes", () => {
    const command = buildApprovalCommand("https://github.com/o/r/pull/42");

    expect(command).toContain("gh pr review https://github.com/o/r/pull/42 --approve");
    expect(command).toContain("gh pr review https://github.com/o/r/pull/42 --request-changes");
    expect(command).toContain("exec ${SHELL:-/bin/zsh} -l");
  });

  test("repeated PR promotion resumes one Review Box", async () => {
    const root = await mkdtemp(join(tmpdir(), "pi-herdr-review-box-"));
    const repo = join(root, "repo");
    const stateRoot = join(root, "state");
    await mkdir(join(repo, ".git"), { recursive: true });

    const calls: Array<{ command: string; args: string[] }> = [];
    let pane = 0;
    let headRefOid = "abc123";
    const pi = {
      exec: async (command: string, args: string[]) => {
        calls.push({ command, args });
        if (command === "git" && args.join(" ") === "rev-parse --show-toplevel") {
          return { code: 0, stdout: `${repo}\n`, stderr: "" };
        }
        if (
          command === "git" &&
          args.join(" ") === "rev-parse --path-format=absolute --git-common-dir"
        ) {
          return { code: 0, stdout: `${join(repo, ".git")}\n`, stderr: "" };
        }
        if (command === "git" && args.join(" ") === "config --get remote.origin.url") {
          return { code: 0, stdout: "git@github.com:nf-core/tools.git\n", stderr: "" };
        }
        if (command === "gh" && args[0] === "pr" && args[1] === "view") {
          return {
            code: 0,
            stdout: JSON.stringify({
              number: 42,
              title: "Review workflow",
              baseRefName: "main",
              headRefName: "feature",
              headRefOid,
              url: "https://github.com/nf-core/tools/pull/42",
            }),
            stderr: "",
          };
        }
        if (command === "git" && args[0] === "worktree" && args[1] === "add") {
          await mkdir(args[3], { recursive: true });
          return { code: 0, stdout: "", stderr: "" };
        }
        if (command === "herdr" && args[0] === "workspace" && args[1] === "create") {
          return {
            code: 0,
            stdout: JSON.stringify({ id: "cli:workspace:create", result: { workspace_id: "w42" } }),
            stderr: "",
          };
        }
        if (command === "herdr" && args[0] === "workspace" && args[1] === "get") {
          return {
            code: 0,
            stdout: JSON.stringify({ id: "cli:workspace:get", result: { workspace_id: "w42" } }),
            stderr: "",
          };
        }
        if (command === "herdr" && args[0] === "tab" && args[1] === "create") {
          pane += 1;
          return {
            code: 0,
            stdout: JSON.stringify({ id: "cli:tab:create", result: { pane_id: `w42:p${pane}` } }),
            stderr: "",
          };
        }
        return { code: 0, stdout: "", stderr: "" };
      },
    } as unknown as ExtensionAPI;

    const created = await openPrReviewWorkspace(pi, { pr: "42" }, repo, { stateRoot });
    const resumed = await openPrReviewWorkspace(pi, { pr: "42" }, repo, { stateRoot });
    headRefOid = "def456";
    const refreshed = await openPrReviewWorkspace(pi, { pr: "42" }, repo, { stateRoot });

    expect(created.action).toBe("created");
    expect(resumed.action).toBe("resumed");
    expect(refreshed.action).toBe("refreshed");
    expect(resumed.workspaceId).toBe("w42");
    expect(
      calls.filter(
        ({ command, args }) => command === "git" && args[0] === "worktree" && args[1] === "add"
      )
    ).toHaveLength(1);
    expect(
      calls.filter(
        ({ command, args }) =>
          command === "herdr" && args[0] === "workspace" && args[1] === "create"
      )
    ).toHaveLength(2);
    expect(
      calls.filter(
        ({ command, args }) => command === "herdr" && args[0] === "workspace" && args[1] === "close"
      )
    ).toHaveLength(1);
  });
});
