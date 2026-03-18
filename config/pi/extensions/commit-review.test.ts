/**
 * Tests for commit review helper logic.
 */

import { describe, expect, it } from "bun:test";
import {
  buildCommitDraftPrompt,
  chooseCommitEditor,
  sanitizeCommitMessage,
  stripMarkdownFences,
  truncateForPrompt,
} from "./lib/commit-review-logic";

describe("stripMarkdownFences", () => {
  it("removes plain fences", () => {
    expect(stripMarkdownFences("```\nfeat: add thing\n```\n")).toBe("feat: add thing");
  });

  it("removes language fences", () => {
    expect(stripMarkdownFences("```text\nfix: keep body\n\nwhy\n```\n")).toBe(
      "fix: keep body\n\nwhy"
    );
  });
});

describe("sanitizeCommitMessage", () => {
  it("passes through a clean commit message", () => {
    expect(sanitizeCommitMessage("feat(pi): add commit review")).toBe(
      "feat(pi): add commit review"
    );
  });

  it("strips fences and quotes", () => {
    expect(sanitizeCommitMessage('"```\nfix: strip wrappers\n```"')).toBe("fix: strip wrappers");
  });

  it("drops verbose preamble before the first conventional line", () => {
    const output = [
      "Here is the best commit message:",
      "",
      "refactor(pi): reuse commit config",
      "",
      "Keep commit review and commit drafting on one model.",
    ].join("\n");

    expect(sanitizeCommitMessage(output)).toBe(
      "refactor(pi): reuse commit config\n\nKeep commit review and commit drafting on one model."
    );
  });
});

describe("chooseCommitEditor", () => {
  it("prefers PI_COMMIT_EDITOR", () => {
    expect(
      chooseCommitEditor({
        PI_COMMIT_EDITOR: "code --wait",
        VISUAL: "nvim",
        EDITOR: "vim",
      })
    ).toBe("code --wait");
  });

  it("ignores non-interactive placeholders", () => {
    expect(
      chooseCommitEditor({
        PI_COMMIT_EDITOR: "true",
        VISUAL: "cat",
        EDITOR: ":",
      })
    ).toBe("nvim");
  });
});

describe("truncateForPrompt", () => {
  it("leaves short text alone", () => {
    expect(truncateForPrompt("abc", 10)).toBe("abc");
  });

  it("truncates long text with a marker", () => {
    const result = truncateForPrompt("a".repeat(40), 20);
    expect(result).toContain("[truncated to 20 chars]");
    expect(result.length).toBeLessThanOrEqual(43);
  });
});

describe("buildCommitDraftPrompt", () => {
  it("includes guidance when present", () => {
    const prompt = buildCommitDraftPrompt({
      stagedStat: "1 file changed",
      stagedDiff: "feat: sample diff",
      guidance: "focus on the pi UX",
    });

    expect(prompt).toContain("Extra guidance: focus on the pi UX");
    expect(prompt).toContain("Staged file stats:");
    expect(prompt).toContain("Staged diff:");
  });
});
