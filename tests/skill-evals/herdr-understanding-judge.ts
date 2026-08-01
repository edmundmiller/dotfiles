import { spawn } from "node:child_process";

/**
 * Blind rubric judge.
 *
 * The scorer's lexical fallback matches key terms, which biases the experiment:
 * the `minimal` and `full` arms inject the reference wording verbatim, so they
 * can score by echoing it, while a semantically correct help-only paraphrase
 * ("background tabs settle on done") gets marked unverified.
 *
 * This judge sees only the explanation and the facts being claimed -- never
 * which arm produced the text, nor the skill wording -- so paraphrase and
 * quotation are treated alike. All facts for one case are graded in a single
 * call, since a per-fact process launch would mean ~72 Codex runs per sweep.
 */
export type BatchGrader = (explanation: string, points: string[]) => Promise<boolean[]>;

const PROMPT = `You are grading whether an explanation demonstrates each listed fact.

Judge MEANING, not wording. A correct paraphrase counts as demonstrated. Using
different vocabulary than the fact statement is fine; quoting a fact verbatim is
neither better nor worse than paraphrasing it. Mark a fact demonstrated only if
the explanation actually conveys it -- not if it is merely adjacent or implied
by a command name.

Return exactly one JSON object mapping each fact's 1-based index to true or
false, with no other text:
{"1": true, "2": false}`;

export function createRubricJudge(): BatchGrader {
  const cache: Record<string, boolean[]> = {};

  return async (explanation: string, points: string[]): Promise<boolean[]> => {
    if (points.length === 0) return [];

    const key = `${explanation}\u0000${points.join("\u0001")}`;
    const cached = cache[key];
    if (cached !== undefined) return cached;

    const verdicts = await judgeBatch(explanation, points);
    cache[key] = verdicts;
    return verdicts;
  };
}

async function judgeBatch(explanation: string, points: string[]): Promise<boolean[]> {
  const facts = points.map((p, i) => `${i + 1}. ${p}`).join("\n");
  const input = `${PROMPT}

<facts>
${facts}
</facts>

<explanation>
${explanation}
</explanation>`;

  const raw = await runJudge(input);
  return parseVerdicts(raw, points.length);
}

export function parseVerdicts(raw: string, count: number): boolean[] {
  const match = raw.match(/\{[\s\S]*\}/);
  if (!match) {
    throw new Error(`judge returned no JSON object: ${raw.slice(0, 200)}`);
  }
  const parsed = JSON.parse(match[0]) as Record<string, unknown>;
  return Array.from({ length: count }, (_, i) => parsed[String(i + 1)] === true);
}

/**
 * Defaults to `claude -p`, matching the harness. The judge needs no tools:
 * it only reads the explanation and the facts.
 */
function runJudge(input: string): Promise<string> {
  const { promise, resolve, reject } = Promise.withResolvers<string>();
  const model = process.env.HERDR_JUDGE_MODEL;
  const backend = process.env.HERDR_JUDGE_RUNNER ?? "claude";

  let command: string;
  let args: string[];
  if (backend === "codex") {
    command = "codex";
    args = [
      "exec",
      "--sandbox",
      "read-only",
      "--ephemeral",
      "--ignore-user-config",
      "--skip-git-repo-check",
      "--color",
      "never",
    ];
    if (model) args.push("--model", model);
    args.push("-");
  } else {
    command = "claude";
    args = ["-p", "--output-format", "text"];
    if (model) args.push("--model", model);
  }

  const child = spawn(command, args, { stdio: ["pipe", "pipe", "pipe"] });
  let stdout = "";
  let stderr = "";
  child.stdout.on("data", (chunk) => {
    stdout += String(chunk);
  });
  child.stderr.on("data", (chunk) => {
    stderr += String(chunk);
  });
  child.on("error", reject);
  child.on("close", (code) => {
    if (code === 0) resolve(stdout);
    else reject(new Error(`judge exited ${code}: ${stderr.slice(-300)}`));
  });
  child.stdin.end(input);
  return promise;
}
