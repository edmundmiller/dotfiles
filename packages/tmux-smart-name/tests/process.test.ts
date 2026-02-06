import { describe, expect, test } from "bun:test";
import { normalizeProgram, AGENT_PROGRAMS } from "../src/process";

describe("normalizeProgram", () => {
  test.each([
    ["node /opt/opencode/bin/oc", "opencode"],
    ["/usr/local/bin/opencode --foo", "opencode"],
    ["oc -m claude", "opencode"],
    ["claude --model sonnet", "claude"],
    ["python script.py", "python"],
    ["nvim file.txt", "nvim"],
    ["pi --help", "pi"],
    ["-zsh", "zsh"],
    ["amp --config foo", "amp"],
    ["", ""],
  ])("%s → %s", (input, expected) => {
    expect(normalizeProgram(input)).toBe(expected);
  });
});

describe("AGENT_PROGRAMS", () => {
  test("includes pi", () => {
    expect(AGENT_PROGRAMS).toContain("pi");
  });

  test("includes all known agents", () => {
    for (const agent of ["opencode", "claude", "amp", "pi"]) {
      expect(AGENT_PROGRAMS).toContain(agent);
    }
  });
});
