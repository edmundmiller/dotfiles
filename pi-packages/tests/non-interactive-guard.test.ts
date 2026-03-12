/**
 * Unit tests: non-interactive command guard.
 *
 * Verifies interactive command detection, safe alternatives, and that normal
 * git workflows stay unblocked.
 */

import { describe, expect, it } from "bun:test";
import {
  getSafeAlternative,
  shouldBlockInteractiveCommand,
  type CommandBlock,
} from "../pi-non-interactive/command-guard";

function expectBlocked(command: string): CommandBlock {
  const decision = shouldBlockInteractiveCommand(command);
  expect(decision).toBeDefined();
  expect(decision?.block).toBe(true);
  return decision!;
}

describe("non-interactive guard: blocked interactive commands", () => {
  const blocked = [
    "git rebase -i HEAD~3",
    "git rebase --interactive main",
    "git add -p",
    "git add --patch src/index.ts",
    "git commit",
    "git commit --amend",
    "git mergetool",
    "git difftool",
    "vim README.md",
    "man git-rebase",
    "less /tmp/log.txt",
  ];

  for (const command of blocked) {
    it(`blocks: ${command}`, () => {
      const decision = expectBlocked(command);
      expect(decision.reason).toContain("Use instead:");
      expect(decision.safeCommand).toBeDefined();
    });
  }
});

describe("non-interactive guard: safe alternatives", () => {
  it("returns deterministic replacement for commit --amend", () => {
    const safe = getSafeAlternative("git commit --amend");
    expect(safe).toBe("git commit --amend --no-edit");
  });

  it("returns deterministic replacement for plain commit", () => {
    const safe = getSafeAlternative("git commit");
    expect(safe).toBe('git commit -m "<message>"');
  });

  it("returns deterministic replacement for patch add", () => {
    const safe = getSafeAlternative("git add -p");
    expect(safe).toBe("git hunks list && git hunks add <hunk-id>");
  });
});

describe("non-interactive guard: non-regression for normal git workflows", () => {
  const allowed = [
    "git status",
    "git diff --staged",
    "git rebase main",
    "git add src/main.ts",
    "git add .",
    "git commit -m 'feat: message'",
    "git commit -am 'feat: message'",
    "git commit --amend --no-edit",
    "git commit --amend -m 'fix: message'",
    "git log --oneline -n 5",
  ];

  for (const command of allowed) {
    it(`allows: ${command}`, () => {
      expect(shouldBlockInteractiveCommand(command)).toBeUndefined();
    });
  }
});
