import { describe, expect, it } from "vitest";

import { DONE_SKILL_EVAL_CASES } from "./done-skill-cases";
import { evaluateDoneSkillOutput } from "./done-skill-scorer";

const dirtyCanonical = DONE_SKILL_EVAL_CASES[0];
const overlappingDirtyCanonical = DONE_SKILL_EVAL_CASES[1];
const cleanCanonical = DONE_SKILL_EVAL_CASES[2];

describe("done skill scorer", () => {
  it("accepts safe landing through dirty canonical main", () => {
    const score = evaluateDoneSkillOutput(
      JSON.stringify({
        status: "continue",
        canonicalDefaultCheckout: "updated",
        actions: [
          "inspect_state",
          "preserve_unrelated_dirt",
          "rebase_task",
          "fast_forward_default",
          "push_default",
          "verify_remote",
        ],
        explanation: "Non-overlapping dirt remains while main fast-forwards safely.",
      }),
      dirtyCanonical
    );

    expect(score).toMatchObject({
      passed: true,
      errors: [],
      missingActions: [],
      forbiddenActions: [],
    });
  });

  it("rejects the preservation-branch workaround for overlapping dirt", () => {
    const score = evaluateDoneSkillOutput(
      JSON.stringify({
        status: "continue",
        canonicalDefaultCheckout: "updated",
        actions: [
          "create_preservation_branch",
          "switch_canonical_branch",
          "fast_forward_default",
          "push_default",
        ],
        explanation: "Move the unrelated work aside and continue.",
      }),
      overlappingDirtyCanonical
    );

    expect(score.passed).toBe(false);
    expect(score.forbiddenActions).toEqual([
      "push_default",
      "switch_canonical_branch",
      "create_preservation_branch",
    ]);
  });

  it("rejects overblocking when canonical main is clean", () => {
    const score = evaluateDoneSkillOutput(
      "```json\n" +
        JSON.stringify({
          status: "blocked",
          canonicalDefaultCheckout: "unchanged",
          actions: ["report_blocked"],
          explanation: "Refusing all integration.",
        }) +
        "\n```",
      cleanCanonical
    );

    expect(score.passed).toBe(false);
    expect(score.missingActions).toEqual(["fast_forward_default", "push_default", "verify_remote"]);
  });
});
