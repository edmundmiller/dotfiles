import { describe, expect, test } from "bun:test";
import {
  buildApprovalCommand,
  buildReadArgs,
  buildReviewAgentName,
  buildReviewPrompt,
  buildWaitArgs,
  findStringKey,
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

  test("wait arguments use the v0.7.5 pane and agent facades", () => {
    expect(
      buildWaitArgs({
        kind: "output",
        paneId: "w2:p4",
        match: "ready",
        regex: false,
        timeoutMs: 30_000,
        lines: 120,
      })
    ).toEqual([
      "pane",
      "wait-output",
      "w2:p4",
      "--match",
      "ready",
      "--timeout",
      "30000",
      "--lines",
      "120",
    ]);
    expect(
      buildWaitArgs({
        kind: "output",
        paneId: "w2:p4",
        match: "passed|failed",
        regex: true,
        timeoutMs: 30_000,
      })
    ).toEqual(["pane", "wait-output", "w2:p4", "--regex", "passed|failed", "--timeout", "30000"]);
    expect(
      buildWaitArgs({
        kind: "agent-status",
        paneId: "w2:p4",
        status: "blocked",
        timeoutMs: 60_000,
      })
    ).toEqual(["agent", "wait", "w2:p4", "--until", "blocked", "--timeout", "60000"]);
  });

  test("detection reads route through the agent facade", () => {
    expect(buildReadArgs("w2:p4", "detection", 120, false)).toEqual([
      "agent",
      "read",
      "w2:p4",
      "--source",
      "detection",
      "--lines",
      "120",
    ]);
    expect(buildReadArgs("w2:p4", "recent", 80, true)).toEqual([
      "pane",
      "read",
      "w2:p4",
      "--source",
      "recent",
      "--lines",
      "80",
      "--ansi",
    ]);
  });

  test("review agents receive strict unique names", () => {
    expect(buildReviewAgentName(42, "w7")).toBe("review-pr-42-w7");
    expect(buildReviewAgentName(42, "workspace:with spaces")).toMatch(/^[a-z][a-z0-9_-]{0,31}$/);
  });
});
