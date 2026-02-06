import { describe, expect, test } from "bun:test";
import { normalizeProgram, AGENT_PROGRAMS } from "../src/process";

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
