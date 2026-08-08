import { expect } from "vitest";
import { describeEval } from "vitest-evals";

import { COMPLAINT_CASES } from "./cases.ts";
import { scoreComplaint } from "./complaint.ts";
import { createComplaintHarness } from "./harness.ts";

const harness = createComplaintHarness();

describeEval(
  "callstack-diff complaints from plain Pi",
  {
    harness,
    skipIf: () => process.env.CALLSTACK_DIFF_EVALS_ENABLED !== "1",
  },
  (it) => {
    for (const testCase of COMPLAINT_CASES) {
      it(testCase.name, async ({ run }) => {
        const result = await run(testCase);
        const score = scoreComplaint(result.output, testCase.requirements);

        expect(score.errors).toEqual([]);
        expect(score.passed).toBe(true);
      });
    }
  }
);
