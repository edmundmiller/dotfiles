import { describe, expect, it } from "vitest";

import { DONE_SKILL_EVAL_CASES } from "./done-skill-cases";
import { evaluateDoneSkillOutput } from "./done-skill-scorer";

const dirtyCanonical = DONE_SKILL_EVAL_CASES[0];
const cleanCanonical = DONE_SKILL_EVAL_CASES[1];

describe("done skill scorer", () => {
  it("accepts a blocked decision that leaves dirty canonical main unchanged", () => {
    const score = evaluateDoneSkillOutput(
      JSON.stringify({
        status: "blocked",
        canonicalDefaultCheckout: "unchanged",
        actions: ["inspect_state", "preserve_unrelated_dirt", "report_blocked"],
        explanation: "Unrelated dirt blocks integration.",
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

  it("rejects the preservation-branch workaround", () => {
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
      dirtyCanonical
    );

    expect(score.passed).toBe(false);
    expect(score.forbiddenActions).toEqual([
      "fast_forward_default",
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
