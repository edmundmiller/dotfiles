import { describe, expect, it } from "bun:test";
import { findBlockedCommand, shouldBlock, BLOCKED_COMMANDS } from "./gitbutler-guard-logic";

describe("findBlockedCommand", () => {
  // Spec: all git write commands are detected
  const writeCommands = [
    "git commit -m 'test'",
    "git checkout main",
    "git switch feature",
    "git rebase main",
    "git merge feature",
    "git reset --hard HEAD~1",
    "git revert abc123",
    "git cherry-pick abc123",
    "git stash",
    "git add .",
    "git restore file.txt",
  ];

  for (const cmd of writeCommands) {
    it(`blocks: ${cmd}`, () => {
      expect(findBlockedCommand(cmd)).toBeDefined();
    });
  }

  // Spec: read-only git commands are allowed
  const readCommands = [
    "git log --oneline",
    "git diff HEAD",
    "git show abc123",
    "git blame file.txt",
    "git status",
    "git branch -a",
    "git remote -v",
    "git ls-files",
    "git rev-parse HEAD",
    "git log --graph --all",
  ];

  for (const cmd of readCommands) {
    it(`allows: ${cmd}`, () => {
      expect(findBlockedCommand(cmd)).toBeUndefined();
    });
  }

  // Regression: git commands embedded in pipelines/subshells
  it("blocks git commit in a pipeline", () => {
    expect(findBlockedCommand("echo 'msg' | git commit -F -")).toBeDefined();
  });

  it("blocks git add in a compound command", () => {
    expect(findBlockedCommand("git add . && git commit -m 'test'")).toBeDefined();
  });

  // Regression: non-git commands containing 'git' substring
  it("allows 'digit' or other words containing git", () => {
    expect(findBlockedCommand("echo digit")).toBeUndefined();
  });
});

describe("shouldBlock", () => {
  const alwaysButler = () => true;
  const neverButler = () => false;

  it("blocks git write in gitbutler workspace", () => {
    const result = shouldBlock("git commit -m 'test'", "/repo", alwaysButler);
    expect(result).toBeDefined();
    expect(result!.block).toBe(true);
    expect(result!.reason).toContain("but commit");
  });

  it("allows git write outside gitbutler workspace", () => {
    const result = shouldBlock("git commit -m 'test'", "/repo", neverButler);
    expect(result).toBeUndefined();
  });

  it("allows git write when no git root", () => {
    const result = shouldBlock("git commit -m 'test'", null, alwaysButler);
    expect(result).toBeUndefined();
  });

  it("allows read-only commands in gitbutler workspace", () => {
    const result = shouldBlock("git log --oneline", "/repo", alwaysButler);
    expect(result).toBeUndefined();
  });

  it("allows non-git commands in gitbutler workspace", () => {
    const result = shouldBlock("ls -la", "/repo", alwaysButler);
    expect(result).toBeUndefined();
  });

  // Spec: each blocked command suggests the correct but equivalent
  it("suggests correct replacement for each command", () => {
    for (const { pattern, replacement } of BLOCKED_COMMANDS) {
      // Build a minimal matching command
      const cmd = pattern.source.replace(/\\b|\\s\+/g, " ").trim();
      const result = shouldBlock(cmd, "/repo", alwaysButler);
      expect(result).toBeDefined();
      expect(result!.reason).toContain(replacement);
    }
  });
});
