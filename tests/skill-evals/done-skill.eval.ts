import { expect } from "vitest";
import { describeEval } from "vitest-evals";

import { createDoneSkillHarness } from "./done-skill-harness";
import { DONE_SKILL_EVAL_CASES } from "./done-skill-cases";
import { evaluateDoneSkillOutput } from "./done-skill-scorer";

const harness = createDoneSkillHarness();

describeEval(
  "Done skill closeout decisions",
  {
    harness,
    skipIf: () => process.env.DONE_SKILL_EVALS_ENABLED !== "1",
  },
  (it) => {
    for (const testCase of DONE_SKILL_EVAL_CASES) {
      it(testCase.name, async ({ run }) => {
        const result = await run(testCase);
        const score = evaluateDoneSkillOutput(result.output, testCase);

        expect(score.errors).toEqual([]);
        expect(score.missingActions).toEqual([]);
        expect(score.forbiddenActions).toEqual([]);
        expect(score.passed).toBe(true);
      });
    }
  }
);
