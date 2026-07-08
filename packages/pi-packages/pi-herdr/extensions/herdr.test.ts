import { describe, expect, test } from "bun:test";
import { buildApprovalCommand, buildReviewPrompt, findStringKey, slugify } from "./herdr.js";

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
});
