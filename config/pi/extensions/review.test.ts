/**
 * Tests for Pi-native review git helpers.
 */

import { describe, expect, it } from "bun:test";
import {
  buildEditorOpenCommand,
  chooseReviewEditor,
  countDiffStats,
  extractHunks,
  formatStatusCode,
  parseStatusPorcelain,
} from "./lib/review-git";

describe("parseStatusPorcelain", () => {
  const status = [
    " M config/pi/extensions/review.ts",
    "M  staged-only.ts",
    "MM both-sides.ts",
    "R  old-name.ts -> new-name.ts",
    "?? untracked.ts",
    "!! ignored-file.ts",
  ].join("\n");

  it("parses worktree entries including renames and untracked files", () => {
    const entries = parseStatusPorcelain(status, "worktree");

    expect(entries.map((entry) => entry.path)).toEqual([
      "config/pi/extensions/review.ts",
      "staged-only.ts",
      "both-sides.ts",
      "new-name.ts",
      "untracked.ts",
    ]);
    expect(entries[3]?.oldPath).toBe("old-name.ts");
    expect(entries[4]?.untracked).toBe(true);
    expect(formatStatusCode(entries[0]!)).toBe("·M");
    expect(formatStatusCode(entries[2]!)).toBe("MM");
  });

  it("filters to staged entries in staged mode", () => {
    const entries = parseStatusPorcelain(status, "staged");

    expect(entries.map((entry) => entry.path)).toEqual([
      "staged-only.ts",
      "both-sides.ts",
      "new-name.ts",
    ]);
  });
});

describe("extractHunks", () => {
  it("extracts old and new line numbers from hunk headers", () => {
    const diff = [
      "diff --git a/file.ts b/file.ts",
      "@@ -1,3 +1,4 @@",
      " line one",
      "@@ -10 +11,2 @@",
      "+line two",
    ].join("\n");

    expect(extractHunks(diff)).toEqual([
      { header: "@@ -1,3 +1,4 @@", oldStartLine: 1, newStartLine: 1 },
      { header: "@@ -10 +11,2 @@", oldStartLine: 10, newStartLine: 11 },
    ]);
  });
});

describe("countDiffStats", () => {
  it("counts added and removed lines without headers", () => {
    const diff = [
      "diff --git a/file.ts b/file.ts",
      "--- a/file.ts",
      "+++ b/file.ts",
      "+new line",
      "+another line",
      "-old line",
      " context",
    ].join("\n");

    expect(countDiffStats(diff)).toEqual({ added: 2, removed: 1 });
  });
});

describe("chooseReviewEditor", () => {
  it("prefers PI_REVIEW_EDITOR", () => {
    expect(
      chooseReviewEditor({
        PI_REVIEW_EDITOR: "code --wait",
        VISUAL: "nvim",
        EDITOR: "vim",
      })
    ).toBe("code --wait");
  });

  it("ignores non-interactive placeholders", () => {
    expect(
      chooseReviewEditor({
        PI_REVIEW_EDITOR: "true",
        VISUAL: "cat",
        EDITOR: ":",
      })
    ).toBe("nvim");
  });
});

describe("buildEditorOpenCommand", () => {
  it("uses --goto for VS Code style editors", () => {
    expect(buildEditorOpenCommand("code --wait", "/tmp/demo.ts", 12)).toBe(
      "code --wait --goto '/tmp/demo.ts:12'"
    );
  });

  it("uses +line for vim-like editors", () => {
    expect(buildEditorOpenCommand("nvim", "/tmp/demo.ts", 12)).toBe("nvim +12 '/tmp/demo.ts'");
  });
});
