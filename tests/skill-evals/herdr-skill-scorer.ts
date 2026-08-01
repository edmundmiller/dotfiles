import { HALLUCINATED_COMMANDS, STALE_SYNTAX, type HerdrSkillEvalCase } from "./herdr-skill-cases";

export type HerdrRunOutput = {
  /** Command sequence the agent proposes. */
  plan: string;
  /** Its stated reasoning, scored against requiredUnderstanding. */
  explanation: string;
  /** How many `--help` invocations the agent made while working. */
  helpInvocations: number;
};

export type HerdrScore = {
  passed: boolean;
  hallucinated: string[];
  staleSyntax: string[];
  missingCommands: string[];
  forbiddenCommands: string[];
  /** Understanding points with no lexical trace; needs rubric grading. */
  unverifiedUnderstanding: string[];
  errors: string[];
};

/** Static stopword table: fixed string keys, membership-only lookups. */
const STOPWORDS: Record<string, true> = {
  the: true,
  a: true,
  an: true,
  and: true,
  or: true,
  but: true,
  so: true,
  to: true,
  of: true,
  in: true,
  on: true,
  at: true,
  is: true,
  are: true,
  was: true,
  be: true,
  been: true,
  its: true,
  it: true,
  that: true,
  this: true,
  than: true,
  then: true,
  may: true,
  can: true,
  cannot: true,
  does: true,
  not: true,
  no: true,
  any: true,
  for: true,
  with: true,
  from: true,
  by: true,
  as: true,
  has: true,
  have: true,
  had: true,
  them: true,
  they: true,
  their: true,
  rather: true,
  before: true,
  after: true,
  while: true,
  already: true,
  additionally: true,
  instead: true,
  other: true,
  same: true,
  new: true,
  into: true,
  never: true,
  those: true,
  which: true,
  what: true,
  when: true,
};

/** Content words carrying the meaning of an understanding point. */
function keyTerms(point: string): string[] {
  return point
    .toLowerCase()
    .replace(/[^a-z0-9_.\-\s]/g, " ")
    .split(/\s+/)
    .filter((w) => w.length > 2 && STOPWORDS[w] !== true);
}

/**
 * Lexical pre-filter for understanding points. A point counts as *possibly*
 * demonstrated when most of its key terms appear; anything below that is
 * reported for rubric grading. This never asserts comprehension on its own.
 */
function understandingCovered(explanation: string, point: string): boolean {
  const haystack = explanation.toLowerCase();
  const terms = keyTerms(point);
  if (terms.length === 0) return true;
  const hits = terms.filter((t) => haystack.includes(t)).length;
  return hits / terms.length >= 0.6;
}

/**
 * Grades whether an explanation demonstrates one understanding point.
 * Supplied by the caller (a model rubric); when absent, the lexical filter is
 * used and every point it cannot confirm is surfaced as a hard failure rather
 * than silently ignored.
 */
export type UnderstandingGrader = (explanation: string, point: string) => boolean;

export function scoreHerdrOutput(
  output: HerdrRunOutput,
  testCase: HerdrSkillEvalCase,
  grade: UnderstandingGrader = understandingCovered
): HerdrScore {
  const errors: string[] = [];
  const plan = output.plan ?? "";
  const explanation = output.explanation ?? "";

  if (plan.trim() === "") errors.push("empty plan");

  // Command syntax is scored against the PLAN only. Scanning the explanation
  // too inverts the signal: "don't use `herdr wait output`, use
  // `pane wait-output`" would count as emitting stale syntax, while merely
  // discussing `agent start` in prose would satisfy a required command the
  // model never planned to run. Prose is the rubric judge's job.
  const haystack = plan.toLowerCase();

  const hallucinated = HALLUCINATED_COMMANDS.filter((c) => haystack.includes(c.toLowerCase()));
  const staleSyntax = STALE_SYNTAX.filter((s) => haystack.includes(s.toLowerCase()));

  const missingCommands = testCase.expected.requiredCommands.filter(
    (c) => !haystack.includes(c.toLowerCase())
  );
  const forbiddenCommands = testCase.expected.forbiddenCommands.filter((c) =>
    haystack.includes(c.toLowerCase())
  );

  // When a case admits several correct approaches, satisfying any one counts.
  const alternatives = testCase.expected.anyOfCommands ?? [];
  const missingAlternative =
    alternatives.length > 0 && !alternatives.some((c) => haystack.includes(c.toLowerCase()));
  if (missingAlternative) {
    missingCommands.push(`one of: ${alternatives.join(" | ")}`);
  }

  const unverifiedUnderstanding = testCase.expected.requiredUnderstanding.filter(
    (point) => !grade(explanation, point)
  );

  return {
    // Understanding is part of the verdict. Without this, semantics and
    // recovery cases pass on command spelling alone, which is precisely the
    // knowledge `--help` already supplies -- the experiment would compare
    // nothing.
    passed:
      errors.length === 0 &&
      hallucinated.length === 0 &&
      staleSyntax.length === 0 &&
      missingCommands.length === 0 &&
      forbiddenCommands.length === 0 &&
      unverifiedUnderstanding.length === 0,
    hallucinated: [...hallucinated],
    staleSyntax: [...staleSyntax],
    missingCommands,
    forbiddenCommands,
    unverifiedUnderstanding,
    errors,
  };
}

export type ArmSummary = {
  arm: string;
  tasks: number;
  passed: number;
  hallucinations: number;
  staleSyntax: number;
  helpInvocations: number;
  byClass: Record<string, { passed: number; total: number }>;
};

export function summarizeArm(
  arm: string,
  results: Array<{ testCase: HerdrSkillEvalCase; output: HerdrRunOutput; score: HerdrScore }>
): ArmSummary {
  const byClass: ArmSummary["byClass"] = {};
  for (const { testCase, score } of results) {
    const bucket = (byClass[testCase.taskClass] ??= { passed: 0, total: 0 });
    bucket.total += 1;
    if (score.passed) bucket.passed += 1;
  }
  return {
    arm,
    tasks: results.length,
    passed: results.filter((r) => r.score.passed).length,
    hallucinations: results.reduce((n, r) => n + r.score.hallucinated.length, 0),
    staleSyntax: results.reduce((n, r) => n + r.score.staleSyntax.length, 0),
    helpInvocations: results.reduce((n, r) => n + (r.output.helpInvocations ?? 0), 0),
    byClass,
  };
}
