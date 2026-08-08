export type ComplaintKind = "bug" | "limitation" | "use-case";

export interface ComplaintRequirements {
  readonly caseId: string;
  readonly commandIncludes: readonly string[];
  readonly expectedIncludes: readonly string[];
  readonly actualIncludes: readonly string[];
  readonly regressionIncludes: readonly string[];
}

export interface ComplaintScore {
  readonly passed: boolean;
  readonly errors: readonly string[];
}

const STRING_FIELDS = [
  "caseId",
  "title",
  "summary",
  "command",
  "expected",
  "actual",
  "regressionTest",
] as const;

function parseObject(output: string): Record<string, unknown> | undefined {
  const trimmed = output.trim();
  const json = trimmed.startsWith("```json")
    ? trimmed.slice("```json".length).replace(/```$/, "").trim()
    : trimmed;

  try {
    const parsed: unknown = JSON.parse(json);
    return typeof parsed === "object" && parsed !== null && !Array.isArray(parsed)
      ? parsed
      : undefined;
  } catch {
    return undefined;
  }
}

function readString(object: Record<string, unknown>, field: string): string | undefined {
  const value = object[field];
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function missingTokens(value: string | undefined, tokens: readonly string[]): string[] {
  const normalized = value?.toLowerCase() ?? "";
  return tokens.filter((token) => !normalized.includes(token.toLowerCase()));
}

function requireTokens(
  errors: string[],
  field: string,
  value: string | undefined,
  tokens: readonly string[]
): void {
  const missing = missingTokens(value, tokens);
  if (missing.length > 0) errors.push(`${field} is missing: ${missing.join(", ")}`);
}

export function scoreComplaint(
  output: string,
  requirements: ComplaintRequirements
): ComplaintScore {
  const object = parseObject(output);
  if (!object) return { passed: false, errors: ["output is not a JSON object"] };

  const errors: string[] = [];
  const values: Record<(typeof STRING_FIELDS)[number], string | undefined> = {
    caseId: readString(object, "caseId"),
    title: readString(object, "title"),
    summary: readString(object, "summary"),
    command: readString(object, "command"),
    expected: readString(object, "expected"),
    actual: readString(object, "actual"),
    regressionTest: readString(object, "regressionTest"),
  };
  const kind = readString(object, "kind");

  for (const field of STRING_FIELDS) {
    if (!values[field]) errors.push(`${field} must be a non-empty string`);
  }
  if (kind !== "bug" && kind !== "limitation" && kind !== "use-case") {
    errors.push("kind must be bug, limitation, or use-case");
  }
  if (values.caseId && values.caseId !== requirements.caseId) {
    errors.push(`caseId must be ${requirements.caseId}`);
  }

  requireTokens(errors, "command", values.command, requirements.commandIncludes);
  requireTokens(errors, "expected", values.expected, requirements.expectedIncludes);
  requireTokens(errors, "actual", values.actual, requirements.actualIncludes);
  requireTokens(errors, "regressionTest", values.regressionTest, requirements.regressionIncludes);

  return { passed: errors.length === 0, errors };
}
