import { describe, expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { buildBaseName, trimName, shortenPath, parsePiFooter } from "../src/naming";

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

describe("parsePiFooter", () => {
  test("extracts branch (non-main)", () => {
    const content = `some output
~/.config/dotfiles (feature-branch)
↑360 ↓100k R31M W1.3M $26.385 (sub) 18.8%/1.0M (auto)`;
    expect(parsePiFooter(content)).toEqual({ branch: "feature-branch" });
  });

  test("omits main branch", () => {
    const content = `~/.config/dotfiles (main)
↑360 ↓100k R31M`;
    expect(parsePiFooter(content)).toEqual({});
  });

  test("omits master branch", () => {
    const content = `~/repo (master)
↑12 ↓1k`;
    expect(parsePiFooter(content)).toEqual({});
  });

  test("extracts session name", () => {
    const content = `~/.config/dotfiles (main) • refactor auth
↑360 ↓100k R31M`;
    expect(parsePiFooter(content)).toEqual({ sessionName: "refactor auth" });
  });

  test("extracts branch + session name", () => {
    const content = `~/project (feat/oauth) • implement login
↑12 ↓1k`;
    expect(parsePiFooter(content)).toEqual({
      branch: "feat/oauth",
      sessionName: "implement login",
    });
  });

  test("returns empty for non-pi content", () => {
    expect(parsePiFooter("random output\nno footer here")).toEqual({});
  });

  test("returns empty for empty string", () => {
    expect(parsePiFooter("")).toEqual({});
  });

  // ── Fixture tests (real captured pane content) ─────────────────────────
  test.each([
    // file, expected — add rows as new fixtures are captured
    ["pi-idle.txt", {}], // main branch omitted, no session name on path line
  ] as const)("fixture %s", (file, expected) => {
    const fixture = readFileSync(join(import.meta.dir, "fixtures", file), "utf8");
    expect(parsePiFooter(fixture)).toEqual(expected);
  });
});

describe("buildBaseName", () => {
  // U+E6AE = nvim nerd font icon, U+F5000-F5002 = agent icons (PUA)
  const NVIM = "\uE6AE";
  const CLAUDE = "\u{F5000}";
  const AMP = "\u{F5001}";
  const OPENCODE = "\u{F5002}";

  test.each([
    // shells: still show path (useful as you cd around; sesh shows project)
    ["zsh", "~/src/personal/repo", undefined, "~/s/p/repo"],
    // editors/agents: sesh shows project — just icon (+ smart context if available)
    ["nvim", "~/src/personal/repo", undefined, NVIM],
    ["python", "~/repo", undefined, "python"],
    ["opencode", "~/src/project", undefined, OPENCODE],
    ["claude", "", undefined, CLAUDE],
    ["pi", "~/src/personal/project", undefined, "π"],
    ["amp", "~/foo", undefined, AMP],
  ] as const)("%s: no project dir in name", (program, path, _ctx, expected) => {
    expect(buildBaseName(program, path)).toBe(expected);
  });

  test("pi with branch (no session name)", () => {
    expect(buildBaseName("pi", "~/.config/dotfiles", { branch: "feat/tmux" })).toBe(
      "π #[dim]tmux#[nodim]"
    );
  });

  test("pi with session name (takes priority over branch)", () => {
    expect(
      buildBaseName("pi", "~/.config/dotfiles", {
        branch: "feat/tmux",
        sessionName: "refactor auth",
      })
    ).toBe("π refactor auth");
  });

  test("pi on main (no branch in context)", () => {
    expect(buildBaseName("pi", "~/.config/dotfiles", {})).toBe("π");
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
    const name = "#[fg=cyan]●#[default] π ~/some/long/path/here";
    const trimmed = trimName(name, 24);
    // Should preserve color codes and trim visible content
    expect(trimmed).toContain("#[fg=cyan]");
    expect(trimmed).toContain("#[default]");
    expect(trimmed).toContain("...");
  });

  test("no trim when color codes make string look long but visible is short", () => {
    const name = "π";
    expect(trimName(name, 24)).toBe(name); // visible: "□ pi" = 4 chars
  });
});
