import { expect } from "vitest";
import { describeEval } from "vitest-evals";

import type { ArmId } from "./herdr-skill-arms";
import { HERDR_SKILL_EVAL_CASES } from "./herdr-skill-cases";
import { createHerdrSkillHarness, parseHerdrOutput } from "./herdr-skill-harness";
import { scoreHerdrOutput } from "./herdr-skill-scorer";
import { createRubricJudge } from "./herdr-understanding-judge";

const harness = createHerdrSkillHarness();

/**
 * Arm comparison. All arms get identical tasks, identical tool access, and
 * identical output contracts; only the injected context differs.
 *
 *   helpOnly - no docs, told to use `herdr --help`
 *   minimal  - help plus the semantics that help cannot express
 *   full     - the current skill (pinned file list)
 *
 * Set HERDR_SKILL_EVAL_ARM to run one arm. Assertions are intentionally
 * recorded rather than hard-failed for the exploratory arms: the point is to
 * measure where each arm breaks, not to gate CI on a model's output.
 */
const ARM = (process.env.HERDR_SKILL_EVAL_ARM ?? "full") as ArmId;
const STRICT = process.env.HERDR_SKILL_EVAL_STRICT === "1";

/**
 * Blind semantic grading is the default. `HERDR_SKILL_EVAL_LEXICAL=1` falls
 * back to key-term matching, which is only valid for debugging: it rewards
 * arms whose injected context contains the reference wording.
 */
const judge = process.env.HERDR_SKILL_EVAL_LEXICAL === "1" ? undefined : createRubricJudge();

describeEval(
  `Herdr skill arm: ${ARM}`,
  {
    harness,
    skipIf: () => process.env.HERDR_SKILL_EVALS_ENABLED !== "1" || process.env.HERDR_ENV !== "1",
  },
  (it) => {
    for (const testCase of HERDR_SKILL_EVAL_CASES) {
      it(`[${testCase.taskClass}] ${testCase.name}`, async ({ run }) => {
        const result = await run({ ...testCase, arm: ARM });
        const output = parseHerdrOutput(result.output);
        const verdicts = judge
          ? await judge(output.explanation, testCase.expected.requiredUnderstanding)
          : undefined;
        const score = scoreHerdrOutput(
          output,
          testCase,
          verdicts
            ? (_explanation, point) =>
                verdicts[testCase.expected.requiredUnderstanding.indexOf(point)] === true
            : undefined
        );

        // Always reported, so a failing arm still yields a readable diagnosis.
        console.info(
          JSON.stringify({
            arm: ARM,
            id: testCase.id,
            taskClass: testCase.taskClass,
            passed: score.passed,
            helpInvocations: output.helpInvocations,
            hallucinated: score.hallucinated,
            staleSyntax: score.staleSyntax,
            missingCommands: score.missingCommands,
            unverifiedUnderstanding: score.unverifiedUnderstanding,
            plan: output.plan,
          })
        );

        // Inventing commands is never acceptable, in any arm.
        expect(score.hallucinated).toEqual([]);
        expect(score.staleSyntax).toEqual([]);

        if (STRICT) {
          expect(score.missingCommands).toEqual([]);
          expect(score.forbiddenCommands).toEqual([]);
          expect(score.passed).toBe(true);
        }
      });
    }
  }
);
