import { describe, expect, test } from "bun:test";
import { buildBaseName, trimName, shortenPath } from "../src/naming";

describe("shortenPath", () => {
  test.each([
    ["~/src/personal/hledger", "~/s/p/hledger"],
    ["~/.config/dotfiles", "~/.c/dotfiles"],
    ["/usr/local/bin", "/u/l/bin"],
    ["~/repo", "~/repo"],
    ["~/a/b/c/d/deep", "~/a/b/c/d/deep"],
    ["/single", "/single"],
    ["relative", "relative"],
    ["", ""],
    ["~", "~"],
    ["~/", "~/"],
  ])("%s → %s", (input, expected) => {
    expect(shortenPath(input)).toBe(expected);
  });
});

describe("buildBaseName", () => {
  test.each([
    ["zsh", "~/src/personal/repo", "~/s/p/repo"],
    ["nvim", "~/src/personal/repo", "nvim: ~/s/p/repo"],
    ["python", "~/repo", "python"],
    ["opencode", "~/src/project", "opencode: ~/s/project"],
    ["claude", "", "claude"],
    ["pi", "~/src/personal/project", "pi: ~/s/p/project"],
    ["amp", "~/foo", "amp: ~/foo"],
  ])("%s + %s → %s", (program, path, expected) => {
    expect(buildBaseName(program, path)).toBe(expected);
  });
});

describe("trimName", () => {
  test("no trim if under limit", () => {
    expect(trimName("short", 10)).toBe("short");
  });

  test("adds ellipsis", () => {
    expect(trimName("abcdefg", 6)).toBe("abc...");
  });

  test("no ellipsis if maxLen <= 3", () => {
    expect(trimName("abcdefg", 3)).toBe("abc");
  });

  test("skips tmux color codes in length calculation", () => {
    const name = "#[fg=cyan]●#[default] pi: ~/some/long/path/here";
    const trimmed = trimName(name, 24);
    // Should preserve color codes and trim visible content
    expect(trimmed).toContain("#[fg=cyan]");
    expect(trimmed).toContain("#[default]");
    expect(trimmed).toContain("...");
  });

  test("no trim when color codes make string look long but visible is short", () => {
    const name = "#[fg=blue]□#[default] pi";
    expect(trimName(name, 24)).toBe(name); // visible: "□ pi" = 4 chars
  });
});
