// Template note: this file demonstrates Vitest Evals + Pi harness wiring.
// Replace createNfTestSkillAgent() with the consuming project's real agent or
// skill runner before treating eval results as meaningful.

import { piAiHarness } from "@vitest-evals/harness-pi-ai";
import { expect } from "vitest";
import { createJudge, describeEval } from "vitest-evals";

type PiRuntime = {
  events?: {
    assistant(content: string): void;
  };
};

function createNfTestSkillAgent() {
  return {
    async run(input: string, runtime: PiRuntime) {
      const output = [
        `Prompt: ${input}`,
        "Read main.nf, the existing .nf.test file, local nextflow.config, and root nf-test.config before editing.",
        "Write one focused nf-test behavior for the missing mode, optional output, config branch, error case, or workflow wiring.",
        "Build realistic inputs with tiny real test data, Channel.of, file(..., checkIfExists: true), and a representative meta map.",
        "Assert process.success and semantic report, log, file, or channel facts before snapshot checks.",
        "Run the narrowest command, for example nf-test test path/to/main.nf.test.",
      ].join("\n");

      runtime.events?.assistant(output);
      return { output };
    },
  };
}

const nfTestSkillHarness = piAiHarness({
  agent: () => createNfTestSkillAgent(),
});

const NfTestSkillJudge = createJudge<string, string>("NfTestSkillJudge", async ({ output }) => {
  const text = output.toLowerCase();
  const required = ["main.nf", "nf-test.config", "channel.of", "process.success", "snapshot"];
  const missing = required.filter((term) => !text.includes(term));

  return {
    score: missing.length === 0 ? 1 : 0,
    metadata: {
      rationale:
        missing.length === 0
          ? "The response follows the nf-test skill process."
          : `Missing nf-test skill requirements: ${missing.join(", ")}`,
    },
  };
});

describeEval("nf-test skill guidance", { harness: nfTestSkillHarness }, (it) => {
  it.for([
    {
      name: "single-end module mode",
      input: "Add an nf-test process test for a new single-end module mode.",
      expected: ["main.nf", "channel.of", "process.success"],
    },
    {
      name: "optional failed reads output",
      input:
        "The optional failed reads output is missing when save_failed is true; capture it in nf-test.",
      expected: ["optional output", "config branch", "snapshot"],
    },
    {
      name: "workflow branch wiring",
      input: "Add workflow-level nf-test coverage for a branch that combines two module outputs.",
      expected: ["workflow wiring", "channel facts", "nf-test test"],
    },
  ])("$name", async ({ input, expected }, { run }) => {
    const result = await run(input);
    const output = result.output.toLowerCase();

    for (const term of expected) {
      expect(output).toContain(term);
    }
    await expect(result).toSatisfyJudge(NfTestSkillJudge);
  });
});
