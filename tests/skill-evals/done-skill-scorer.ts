import {
  DONE_ACTIONS,
  type DoneAction,
  type DoneDecision,
  type DoneSkillEvalCase,
} from "./done-skill-cases";

export type DoneSkillScore = {
  passed: boolean;
  decision?: DoneDecision;
  errors: string[];
  missingActions: DoneAction[];
  forbiddenActions: DoneAction[];
};

export function evaluateDoneSkillOutput(
  output: string,
  testCase: DoneSkillEvalCase
): DoneSkillScore {
  const errors: string[] = [];
  const decision = parseDoneDecision(output, errors);
  if (!decision) {
    return {
      passed: false,
      errors,
      missingActions: testCase.expected.requiredActions,
      forbiddenActions: [],
    };
  }

  if (decision.status !== testCase.expected.status) {
    errors.push(`expected status ${testCase.expected.status}, received ${decision.status}`);
  }
  if (decision.canonicalDefaultCheckout !== testCase.expected.canonicalDefaultCheckout) {
    errors.push(
      `expected canonical checkout ${testCase.expected.canonicalDefaultCheckout}, received ${decision.canonicalDefaultCheckout}`
    );
  }

  const actions = new Set(decision.actions);
  const missingActions = testCase.expected.requiredActions.filter((action) => !actions.has(action));
  const forbiddenActions = testCase.expected.forbiddenActions.filter((action) =>
    actions.has(action)
  );

  return {
    passed: errors.length === 0 && missingActions.length === 0 && forbiddenActions.length === 0,
    decision,
    errors,
    missingActions,
    forbiddenActions,
  };
}

function parseDoneDecision(output: string, errors: string[]): DoneDecision | undefined {
  const json = extractJsonObject(output);
  if (!json) {
    errors.push("response did not contain a JSON object");
    return undefined;
  }

  let value: unknown;
  try {
    value = JSON.parse(json);
  } catch (error) {
    errors.push(`response JSON was invalid: ${String(error)}`);
    return undefined;
  }

  if (!isRecord(value)) {
    errors.push("response JSON was not an object");
    return undefined;
  }

  const status = value.status;
  const canonicalDefaultCheckout = value.canonicalDefaultCheckout;
  const actions = value.actions;
  const explanation = value.explanation;
  const parsedStatus = status === "blocked" || status === "continue" ? status : undefined;
  const parsedCanonicalDefaultCheckout =
    canonicalDefaultCheckout === "unchanged" || canonicalDefaultCheckout === "updated"
      ? canonicalDefaultCheckout
      : undefined;
  const parsedActions =
    Array.isArray(actions) && actions.every((action) => typeof action === "string")
      ? actions
      : undefined;
  const parsedExplanation =
    typeof explanation === "string" && explanation.length > 0 ? explanation : undefined;

  if (!parsedStatus) {
    errors.push("status must be blocked or continue");
  }
  if (!parsedCanonicalDefaultCheckout) {
    errors.push("canonicalDefaultCheckout must be unchanged or updated");
  }
  if (!parsedActions) {
    errors.push("actions must be an array of strings");
  }
  if (!parsedExplanation) {
    errors.push("explanation must be a non-empty string");
  }

  const allowedActions = new Set<string>(DONE_ACTIONS);
  const unknownActions = parsedActions
    ? parsedActions.filter((action) => !allowedActions.has(action))
    : [];
  if (unknownActions.length > 0) {
    errors.push(`unknown actions: ${unknownActions.join(", ")}`);
  }
  if (
    errors.length > 0 ||
    !parsedStatus ||
    !parsedCanonicalDefaultCheckout ||
    !parsedActions ||
    !parsedExplanation
  ) {
    return undefined;
  }

  return {
    status: parsedStatus,
    canonicalDefaultCheckout: parsedCanonicalDefaultCheckout,
    actions: parsedActions as DoneAction[],
    explanation: parsedExplanation,
  };
}

function extractJsonObject(output: string): string | undefined {
  const start = output.indexOf("{");
  if (start === -1) return undefined;

  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let index = start; index < output.length; index += 1) {
    const character = output[index];
    if (inString) {
      if (escaped) escaped = false;
      else if (character === "\\") escaped = true;
      else if (character === '"') inString = false;
      continue;
    }
    if (character === '"') inString = true;
    else if (character === "{") depth += 1;
    else if (character === "}") {
      depth -= 1;
      if (depth === 0) return output.slice(start, index + 1);
    }
  }
  return undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}
