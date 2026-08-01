import { describe, expect, it } from "vitest";

import { HERDR_SKILL_EVAL_CASES, type HerdrSkillEvalCase } from "./herdr-skill-cases";
import { scoreHerdrOutput, summarizeArm, type HerdrRunOutput } from "./herdr-skill-scorer";
import { countHelpCalls } from "./herdr-skill-harness";
import { parseVerdicts } from "./herdr-understanding-judge";

const startCase = HERDR_SKILL_EVAL_CASES.find((c) => c.id === "start-and-prompt")!;
const shapeCase = HERDR_SKILL_EVAL_CASES.find((c) => c.id === "workspace-root-pane-shape")!;
const doneCase = HERDR_SKILL_EVAL_CASES.find((c) => c.id === "background-completion-unfocused")!;

function output(over: Partial<HerdrRunOutput> = {}): HerdrRunOutput {
  return { plan: "", explanation: "", helpInvocations: 0, ...over };
}

describe("scoreHerdrOutput", () => {
  it("passes a correct 0.7.5 answer", () => {
    const score = scoreHerdrOutput(
      output({
        plan: [
          "herdr pane split --current --direction right --no-focus",
          "herdr agent start helper --kind omp --pane w1:p2",
          "herdr agent prompt helper 'summarize the README' --wait --until done --timeout 120000",
          "herdr agent read helper --source recent-unwrapped --lines 100",
        ].join("\n"),
        explanation:
          "agent start requires an existing pane already sitting at an interactive shell prompt, and agent prompt submits the text together with Enter",
      }),
      startCase
    );

    expect(score.hallucinated).toEqual([]);
    expect(score.missingCommands).toEqual([]);
    expect(score.unverifiedUnderstanding).toEqual([]);
    expect(score.passed).toBe(true);
  });

  it("flags an invented subcommand", () => {
    const score = scoreHerdrOutput(
      output({ plan: "herdr agents\nherdr agent status helper" }),
      startCase
    );

    expect(score.hallucinated).toContain("herdr agents");
    expect(score.hallucinated).toContain("herdr agent status");
    expect(score.passed).toBe(false);
  });

  it("flags pre-0.7.5 flags that no longer exist", () => {
    const score = scoreHerdrOutput(
      output({
        plan: "herdr agent wait worker --status done --timeout 60000",
        explanation: "wait for the done state",
      }),
      doneCase
    );

    expect(score.staleSyntax).toContain("--status done");
    expect(score.passed).toBe(false);
  });

  it("catches the jq key-path trap on workspace create", () => {
    const score = scoreHerdrOutput(
      output({
        plan: "herdr workspace create --cwd /tmp/demo --label demo --no-focus | jq -r '.result.pane.pane_id'",
        explanation: "parse the pane id and run the tests there",
      }),
      shapeCase
    );

    expect(score.forbiddenCommands).toContain(".result.pane.pane_id");
    // Neither correct extraction method is present, so the alternatives fail.
    expect(score.missingCommands).toContain("one of: root_pane | extract_ids.py");
    expect(score.passed).toBe(false);
  });

  it("fails correct commands that never demonstrate the reasoning", () => {
    const score = scoreHerdrOutput(
      output({
        plan: [
          "herdr pane split --current --direction right --no-focus",
          "herdr agent start helper --kind omp --pane w1:p2",
          "herdr agent prompt helper 'summarize' --wait --until done",
          "herdr agent read helper --lines 100",
        ].join("\n"),
        explanation: "ran the commands",
      }),
      startCase
    );

    // Command spelling is discoverable from --help; the experiment only learns
    // something if the explanation is scored too.
    expect(score.missingCommands).toEqual([]);
    expect(score.unverifiedUnderstanding.length).toBeGreaterThan(0);
    expect(score.passed).toBe(false);
  });

  it("accepts a supplied rubric grader in place of the lexical filter", () => {
    const terse = output({
      plan: "herdr agent wait worker --until done --timeout 60000",
      explanation: "background tabs settle on done; the CLI never marks them seen",
    });

    const lexical = scoreHerdrOutput(terse, doneCase);
    expect(lexical.unverifiedUnderstanding.length).toBeGreaterThan(0);

    const rubric = scoreHerdrOutput(terse, doneCase, () => true);
    expect(rubric.unverifiedUnderstanding).toEqual([]);
    expect(rubric.passed).toBe(true);
  });

  it("reports an empty plan as an error rather than a silent pass", () => {
    const score = scoreHerdrOutput(output({ plan: "   " }), startCase);

    expect(score.errors).toContain("empty plan");
    expect(score.passed).toBe(false);
  });
});

describe("summarizeArm", () => {
  it("aggregates pass rate and help usage per task class", () => {
    const cases: HerdrSkillEvalCase[] = [startCase, doneCase];
    const results = cases.map((testCase, index) => {
      const out = output({
        plan: index === 0 ? "herdr pane split" : "herdr agents",
        helpInvocations: index === 0 ? 3 : 1,
      });
      return { testCase, output: out, score: scoreHerdrOutput(out, testCase) };
    });

    const summary = summarizeArm("helpOnly", results);

    expect(summary.tasks).toBe(2);
    expect(summary.hallucinations).toBe(1);
    expect(summary.helpInvocations).toBe(4);
    expect(summary.byClass["syntax-discoverable"]?.total).toBe(1);
    expect(summary.byClass["semantics"]?.total).toBe(1);
  });
});

describe("parseVerdicts", () => {
  it("maps 1-based indices to booleans", () => {
    expect(parseVerdicts('{"1": true, "2": false, "3": true}', 3)).toEqual([true, false, true]);
  });

  it("tolerates prose around the JSON object", () => {
    expect(parseVerdicts('Here is my grading:\n{"1": false}\nDone.', 1)).toEqual([false]);
  });

  it("treats a missing index as not demonstrated rather than passing it", () => {
    expect(parseVerdicts('{"1": true}', 3)).toEqual([true, false, false]);
  });

  it("throws when the judge returns no JSON at all", () => {
    expect(() => parseVerdicts("I could not decide.", 2)).toThrow(/no JSON object/);
  });
});

describe("command scoring scope", () => {
  const goodPlan = [
    "herdr pane split --current --direction right --no-focus",
    "herdr agent start helper --kind omp --pane w1:p2",
    "herdr agent prompt helper 'summarize' --wait --until done",
    "herdr agent read helper --lines 100",
  ].join("\n");

  it("does not penalize an explanation that warns against stale syntax", () => {
    const score = scoreHerdrOutput(
      output({
        plan: goodPlan,
        explanation:
          "Note that `herdr wait` and `agent send` no longer exist in 0.7.5; use `agent prompt --wait --until` instead.",
      }),
      startCase,
      () => true
    );

    expect(score.staleSyntax).toEqual([]);
    expect(score.hallucinated).toEqual([]);
    expect(score.passed).toBe(true);
  });

  it("does not let prose satisfy a required command the plan omits", () => {
    const score = scoreHerdrOutput(
      output({
        plan: "echo 'thinking about it'",
        explanation:
          "I would use herdr agent start and herdr agent prompt --wait --until done here.",
      }),
      startCase,
      () => true
    );

    expect(score.missingCommands.length).toBeGreaterThan(0);
    expect(score.passed).toBe(false);
  });

  it("still flags dead commands and stale flags present in the plan", () => {
    const dead = scoreHerdrOutput(
      output({ plan: "herdr agent send helper 'go'", explanation: "" }),
      startCase,
      () => true
    );
    expect(dead.hallucinated).toContain("herdr agent send ");
    expect(dead.passed).toBe(false);

    const stale = scoreHerdrOutput(
      output({ plan: "herdr agent prompt helper 'go' --wait --status done", explanation: "" }),
      startCase,
      () => true
    );
    expect(stale.staleSyntax).toContain("--status done");
    expect(stale.passed).toBe(false);
  });
});

describe("countHelpCalls", () => {
  it("counts only help invocations from the shim log", () => {
    const log = [
      "agent --help",
      "agent list",
      "pane split --current",
      "pane wait-output -h",
      "help",
      "",
    ].join("\n");
    expect(countHelpCalls(log)).toBe(3);
  });

  it("returns zero for an empty log", () => {
    expect(countHelpCalls("")).toBe(0);
  });

  it("does not count a bare mention of help inside an argument", () => {
    expect(countHelpCalls("agent prompt worker 'please help me'")).toBe(0);
  });
});

describe("anyOfCommands", () => {
  const shapeCase = HERDR_SKILL_EVAL_CASES.find((c) => c.id === "workspace-root-pane-shape")!;

  it("accepts the extract_ids.py helper the skill recommends", () => {
    const score = scoreHerdrOutput(
      output({
        plan: [
          "CREATE=$(herdr workspace create --cwd /tmp/demo --label demo --no-focus)",
          'P=$(printf "%s" "$CREATE" | ~/.agents/skills/herdr/scripts/extract_ids.py pane)',
          'herdr pane run "$P" "npm test"',
        ].join("\n"),
      }),
      shapeCase,
      () => true
    );
    expect(score.missingCommands).toEqual([]);
    expect(score.passed).toBe(true);
  });

  it("accepts the literal root_pane key path", () => {
    const score = scoreHerdrOutput(
      output({
        plan: [
          "CREATE=$(herdr workspace create --cwd /tmp/demo --label demo --no-focus)",
          'P=$(echo "$CREATE" | python3 -c \'import sys,json;print(json.load(sys.stdin)["result"]["root_pane"]["pane_id"])\')',
          'herdr pane run "$P" "npm test"',
        ].join("\n"),
      }),
      shapeCase,
      () => true
    );
    expect(score.missingCommands).toEqual([]);
    expect(score.passed).toBe(true);
  });

  it("still fails when neither approach appears", () => {
    const score = scoreHerdrOutput(
      output({
        plan: [
          "herdr workspace create --cwd /tmp/demo --label demo --no-focus",
          'herdr pane run "$SOMEHOW" "npm test"',
        ].join("\n"),
      }),
      shapeCase,
      () => true
    );
    expect(score.missingCommands.some((m) => m.startsWith("one of:"))).toBe(true);
    expect(score.passed).toBe(false);
  });
});
