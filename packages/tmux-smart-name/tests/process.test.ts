import { describe, expect, test } from "bun:test";
import { normalizeProgram, AGENT_PROGRAMS, extractFilenameFromArgs } from "../src/process";

describe("normalizeProgram", () => {
  test.each([
    // Opencode + alias
    ["node /opt/opencode/bin/oc", "opencode"],
    ["/usr/local/bin/opencode --foo", "opencode"],
    ["oc -m claude", "opencode"],

    // Claude Code
    ["claude --model sonnet", "claude"],

    // pi
    ["pi --help", "pi"],

    // Amp
    ["amp --config foo", "amp"],

    // Aider
    ["aider --model gpt-4", "aider"],

    // Goose
    ["goose session start", "goose"],

    // Codex
    ["codex --full-auto", "codex"],
    ["codex-cli --full-auto", "codex"],
    ["node /opt/homebrew/bin/codex", "codex"],
    ["node /Users/me/.npm/_npx/123/node_modules/@openai/codex/dist/cli.js", "codex"],
    ["OPENAI_API_KEY=foo codex exec --help", "codex"],

    // Gemini
    ["gemini chat", "gemini"],

    // Mentat
    ["mentat .", "mentat"],

    // Multi-word agents
    ["gpt-engineer start", "gpt-engineer"],
    ["gpt-pilot run", "gpt-pilot"],

    // Non-agents
    ["python script.py", "python"],
    ["nvim file.txt", "nvim"],
    ["-zsh", "zsh"],
    ["", ""],
  ])("%s → %s", (input, expected) => {
    expect(normalizeProgram(input)).toBe(expected);
  });
});

describe("extractFilenameFromArgs", () => {
  test.each([
    ["nvim src/index.ts", "index.ts"],
    ["nvim /long/path/Button.tsx", "Button.tsx"],
    ["vim -c 'autocmd' file.go", "file.go"],
    ["nvim +10 README.md", "README.md"],
    ["nvim -c cmd -u NONE config.lua", "config.lua"],
    ["nvim", ""], // no args
    ["nvim .", ""], // bare dot skipped
    ["nvim ..", ""], // double-dot skipped
    ["nvim file1.ts file2.ts", "file1.ts"], // first wins
  ])("%s → %s", (cmdline, expected) => {
    expect(extractFilenameFromArgs(cmdline)).toBe(expected);
  });
});

describe("AGENT_PROGRAMS", () => {
  test("includes all major agents", () => {
    const expected = [
      "opencode",
      "claude",
      "amp",
      "pi",
      "aider",
      "goose",
      "codex",
      "gemini",
      "mentat",
      "cursor",
      "zed",
    ];
    for (const agent of expected) {
      expect(AGENT_PROGRAMS).toContain(agent);
    }
  });
});
