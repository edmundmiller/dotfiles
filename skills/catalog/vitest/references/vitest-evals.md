# Vitest Evals Reference

Use this reference when adding eval coverage for a skill, Pi agent, toolset, or runtime-compatible `run(input, runtime)` entrypoint.

## Install

```bash
pnpm add -D vitest vitest-evals @vitest-evals/harness-pi-ai
```

## Eval config

Keep evals on a separate Vitest command and config so provider timeouts, replay settings, reporters, and eval-only includes do not affect unit tests.

```ts
// vitest.evals.config.ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    include: ["evals/**/*.eval.ts"],
    testTimeout: 30_000,
    hookTimeout: 30_000,
    reporters: ["vitest-evals/reporter"],
    env: {
      VITEST_EVALS_REPLAY_MODE: process.env.VITEST_EVALS_REPLAY_MODE ?? "auto",
      VITEST_EVALS_REPLAY_DIR: ".vitest-evals/recordings",
    },
  },
});
```

```json
{
  "scripts": {
    "evals": "vitest run --config vitest.evals.config.ts",
    "evals:record": "VITEST_EVALS_REPLAY_MODE=record vitest run --config vitest.evals.config.ts"
  }
}
```

## Pi harness shape

Use `piAiHarness` when the target exposes a Pi agent, toolset, or `run(input, runtime)` entrypoint. The harness creates the agent per run, normalizes output, and records transcript/tool/runtime data for assertions and judges.

```ts
import { piAiHarness } from "@vitest-evals/harness-pi-ai";

import { createSkillAgent } from "../src/skill-agent";
function buildInstructions(input: string) {
  return `Follow the Vitest testing skill for: ${input}`;
}

export const skillHarness = piAiHarness({
  agent: ({ input }) =>
    createSkillAgent({
      instructions: buildInstructions(input),
    }),
});
```

Return `{ output }` from the Pi entrypoint when tests or judges should assert a parsed domain value.

## Eval shape

Write evals against the harness, not the Pi runtime. Keep deterministic expectations in the case row; add judges for reusable scored checks.

```ts
import { expect } from "vitest";
import { createJudge, describeEval } from "vitest-evals";

import { skillHarness } from "./skillHarness";

const SkillProcessJudge = createJudge<string, string>("SkillProcessJudge", async ({ output }) => {
  const passed = output.toLowerCase().includes("targeted command");

  return {
    score: passed ? 1 : 0,
    metadata: {
      rationale: passed
        ? "Output includes targeted command."
        : `Missing targeted command: ${output}`,
    },
  };
});

describeEval("skill behavior", { harness: skillHarness }, (it) => {
  it.for([
    {
      name: "simple behavior",
      input: "Add one behavior test for the formatter.",
      expected: ["public seam", "targeted command"],
    },
  ])("$name", async ({ input, expected }, { run }) => {
    const result = await run(input);
    const output = result.output.toLowerCase();

    for (const term of expected) {
      expect(output).toContain(term);
    }
    await expect(result).toSatisfyJudge(SkillProcessJudge);
  });
});
```

## Template caveat

`evals/skill.eval.ts` in this skill is a self-contained template. Replace the stub `createVitestSkillAgent()` with the consuming project's real Pi-compatible agent or skill runner before treating results as meaningful.
