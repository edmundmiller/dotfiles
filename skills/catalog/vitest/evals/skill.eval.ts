// Template note: this file demonstrates Vitest Evals + Pi harness wiring.
// Replace createVitestSkillAgent() with the consuming project's real agent or
// skill runner before treating eval results as meaningful.

import { piAiHarness } from "@vitest-evals/harness-pi-ai";
import { expect } from "vitest";
import { createJudge, describeEval } from "vitest-evals";

type PiRuntime = {
  events?: {
    assistant(content: string): void;
  };
};

function createVitestSkillAgent() {
  return {
    async run(input: string, runtime: PiRuntime) {
      const output = [
        `Prompt: ${input}`,
        "Read the public seam and one nearby Vitest test before writing assertions.",
        "Write one red behavior test against observable output, thrown error, emitted request, or persisted state.",
        "Use deterministic doubles at external edges: fake timers, stubbed globals, captured fetch, or module mocks.",
        "Run the narrowest non-watch command, for example vitest run path/to/file.test.ts.",
      ].join("\n");

      runtime.events?.assistant(output);
      return { output };
    },
  };
}

const vitestSkillHarness = piAiHarness({
  agent: () => createVitestSkillAgent(),
});

const VitestSkillJudge = createJudge<string, string>("VitestSkillJudge", async ({ output }) => {
  const text = output.toLowerCase();
  const required = [
    "nearby vitest test",
    "red behavior test",
    "deterministic doubles",
    "vitest run",
  ];
  const missing = required.filter((term) => !text.includes(term));

  return {
    score: missing.length === 0 ? 1 : 0,
    metadata: {
      rationale:
        missing.length === 0
          ? "The response follows the Vitest skill process."
          : `Missing Vitest skill requirements: ${missing.join(", ")}`,
    },
  };
});

describeEval("vitest skill guidance", { harness: vitestSkillHarness }, (it) => {
  it.for([
    {
      name: "pure function test",
      input: "Add a Vitest test for a pure TypeScript function that formats a display name.",
      expected: ["public seam", "one red behavior test", "vitest run"],
    },
    {
      name: "time-sensitive retry bug",
      input: "Fix a bug where retry scheduling uses wall-clock time incorrectly.",
      expected: ["fake timers", "deterministic doubles", "thrown error"],
    },
    {
      name: "worker with fetch calls",
      input: "Test a worker that calls OAuth, fetches calendar events, and writes travel blocks.",
      expected: ["captured fetch", "emitted request", "persisted state"],
    },
  ])("$name", async ({ input, expected }, { run }) => {
    const result = await run(input);
    const output = result.output.toLowerCase();

    for (const term of expected) {
      expect(output).toContain(term);
    }
    await expect(result).toSatisfyJudge(VitestSkillJudge);
  });
});
