import { spawnSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, test } from "vitest";

import { scoreComplaint } from "../evals/complaint.ts";
import { TOOL_EXTENSION } from "../evals/harness.ts";
import { buildPiArguments } from "../evals/pi.ts";

const requirements = {
  caseId: "imported-helper-ambiguity",
  commandIncludes: ["csd", "main", "app.ts", "distractor.ts", "intended.ts"],
  expectedIncludes: ["intendedLeaf"],
  actualIncludes: ["distractorLeaf"],
  regressionIncludes: ["import", "intendedLeaf"],
};

describe("complaint scorer", () => {
  test("accepts a specific, reproducible agent complaint", () => {
    const output = JSON.stringify({
      caseId: "imported-helper-ambiguity",
      kind: "limitation",
      title: "Imported helper resolves to an unrelated same-named function",
      summary: "The static tree contradicts the explicit import in app.ts.",
      command: "csd main app.ts distractor.ts intended.ts --theme none",
      expected: "helper should expand to intendedLeaf because app.ts imports it from intended.ts.",
      actual: "helper expands to distractorLeaf from distractor.ts.",
      regressionTest:
        "Add an import-aware test that expects intendedLeaf and excludes distractorLeaf.",
    });

    expect(scoreComplaint(output, requirements)).toEqual({ passed: true, errors: [] });
  });

  test("rejects vague prose without command or observed evidence", () => {
    const output = JSON.stringify({
      caseId: "imported-helper-ambiguity",
      kind: "bug",
      title: "Resolution seems wrong",
      summary: "Please improve it.",
      command: "csd",
      expected: "The right result.",
      actual: "The wrong result.",
      regressionTest: "Add a test.",
    });

    const score = scoreComplaint(output, requirements);

    expect(score.passed).toBe(false);
    expect(score.errors).toEqual([
      "command is missing: main, app.ts, distractor.ts, intended.ts",
      "expected is missing: intendedLeaf",
      "actual is missing: distractorLeaf",
      "regressionTest is missing: import, intendedLeaf",
    ]);
  });

  test("rejects malformed agent output without throwing", () => {
    expect(scoreComplaint("not json", requirements)).toEqual({
      passed: false,
      errors: ["output is not a JSON object"],
    });
  });
});

describe("plain Pi boundary", () => {
  test("disables personal resources, context files, writes, and sessions", () => {
    expect(
      buildPiArguments("inspect the fixture", {
        extension: "/tmp/callstack-diff-tool.mjs",
        provider: "openai",
        model: "gpt-5-mini",
      })
    ).toEqual([
      "--print",
      "--mode",
      "text",
      "--no-session",
      "--no-extensions",
      "--no-skills",
      "--no-prompt-templates",
      "--no-themes",
      "--no-context-files",
      "--tools",
      "read,callstack_diff",
      "--extension",
      "/tmp/callstack-diff-tool.mjs",
      "--provider",
      "openai",
      "--model",
      "gpt-5-mini",
      "inspect the fixture",
    ]);
  });

  test.fails("emits a syntactically valid package tool extension", () => {
    const directory = mkdtempSync(join(tmpdir(), "callstack-diff-extension-test-"));
    const extension = join(directory, "callstack-diff-tool.mjs");
    try {
      writeFileSync(extension, TOOL_EXTENSION);
      const result = spawnSync(process.execPath, ["--check", extension], { encoding: "utf8" });

      expect(result.stderr).toBe("");
      expect(result.status).toBe(0);
    } finally {
      rmSync(directory, { recursive: true, force: true });
    }
  });
});
