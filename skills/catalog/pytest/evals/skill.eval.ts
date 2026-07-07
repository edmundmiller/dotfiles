// Template note: this file demonstrates Vitest Evals + Pi harness wiring.
// Replace createPytestSkillAgent() with the consuming project's real agent or
// skill runner before treating eval results as meaningful.

import { piAiHarness } from "@vitest-evals/harness-pi-ai";
import { expect } from "vitest";
import { createJudge, describeEval } from "vitest-evals";

type PiRuntime = {
  events?: {
    assistant(content: string): void;
  };
};

function createPytestSkillAgent() {
  return {
    async run(input: string, runtime: PiRuntime) {
      const output = [
        `Prompt: ${input}`,
        "Read the target module, existing tests, and pytest config before choosing the seam.",
        "Write one red contract test through a public function, CLI, file output, exception, or serialized value.",
        "Control state with tmp_path, monkeypatch, fixtures, or small in-memory fakes.",
        "Use strict xfail only for a separate regression-test commit that must stay green before the fix.",
        "Run the narrowest command, for example uv run pytest tests/test_name.py -q.",
      ].join("\n");

      runtime.events?.assistant(output);
      return { output };
    },
  };
}

const pytestSkillHarness = piAiHarness({
  agent: () => createPytestSkillAgent(),
});

const PytestSkillJudge = createJudge<string, string>("PytestSkillJudge", async ({ output }) => {
  const text = output.toLowerCase();
  const required = ["pytest config", "red contract test", "tmp_path", "monkeypatch", "pytest"];
  const missing = required.filter((term) => !text.includes(term));

  return {
    score: missing.length === 0 ? 1 : 0,
    metadata: {
      rationale:
        missing.length === 0
          ? "The response follows the pytest skill process."
          : `Missing pytest skill requirements: ${missing.join(", ")}`,
    },
  };
});

describeEval("pytest skill guidance", { harness: pytestSkillHarness }, (it) => {
  it.for([
    {
      name: "pure formatter regression",
      input: "Add a pytest test for a function that strips markdown fences.",
      expected: ["public function", "red contract test", "pytest"],
    },
    {
      name: "malformed json bug",
      input:
        "Capture the bug where malformed JSON should preserve the raw input instead of raising.",
      expected: ["strict xfail", "regression-test commit", "exception"],
    },
    {
      name: "cli archive writer",
      input: "Test a CLI that writes archives and reads fixture conversations.",
      expected: ["tmp_path", "fixtures", "file output"],
    },
  ])("$name", async ({ input, expected }, { run }) => {
    const result = await run(input);
    const output = result.output.toLowerCase();

    for (const term of expected) {
      expect(output).toContain(term);
    }
    await expect(result).toSatisfyJudge(PytestSkillJudge);
  });
});
