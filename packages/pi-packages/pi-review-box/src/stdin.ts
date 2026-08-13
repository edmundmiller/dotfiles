/**
 * Stdin reading and JSON parsing/validation.
 *
 * The bridge reads exactly one JSON object from stdin with the ghui
 * PullRequestItem shape. Malformed/empty/non-object/trailing-garbage
 * stdin is rejected. Unknown extra fields are tolerated.
 */

export type ParsedStdin = {
  repository: string;
  number: number;
  headRefOid: string;
  headRefName: string;
  title: string;
  url: string;
};

const REPO_PATTERN = /^[^/]+\/[^/]+$/;

/**
 * Validate a parsed JSON value as a ParsedStdin.
 * Throws a descriptive error on any validation failure.
 */
export function validateStdin(data: unknown): ParsedStdin {
  if (typeof data !== "object" || data === null || Array.isArray(data)) {
    throw new Error("stdin must be a single JSON object");
  }

  const obj = data as Record<string, unknown>;
  const { repository, number, headRefOid, headRefName, title, url } = obj;

  if (typeof repository !== "string" || !REPO_PATTERN.test(repository)) {
    throw new Error("field 'repository' must be a string matching owner/name");
  }

  if (typeof number !== "number" || !Number.isInteger(number) || number <= 0) {
    throw new Error("field 'number' must be a positive integer");
  }

  if (typeof headRefOid !== "string" || headRefOid.length === 0) {
    throw new Error("field 'headRefOid' must be a non-empty string");
  }

  if (typeof headRefName !== "string" || headRefName.length === 0) {
    throw new Error("field 'headRefName' must be a non-empty string");
  }

  if (typeof title !== "string" || title.length === 0) {
    throw new Error("field 'title' must be a non-empty string");
  }

  if (typeof url !== "string" || url.length === 0) {
    throw new Error("field 'url' must be a non-empty string");
  }

  return { repository, number, headRefOid, headRefName, title, url };
}

/**
 * Read all of stdin as a string.
 */
export async function readStdin(): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) {
    chunks.push(Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8");
}

/**
 * Read and parse stdin as exactly one JSON object.
 * JSON.parse rejects trailing garbage, so "{...valid...} junk" exits 2.
 */
export async function readAndParseStdin(): Promise<ParsedStdin> {
  const text = await readStdin();

  if (text.trim().length === 0) {
    throw new Error("stdin is empty");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new Error("stdin is not valid JSON");
  }

  return validateStdin(parsed);
}
