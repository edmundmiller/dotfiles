import { mkdtempSync, readFileSync, readdirSync, rmSync } from "node:fs";
import { spawn } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

import { createHarness } from "vitest-evals";

import { DONE_ACTIONS, type DoneSkillEvalCase } from "./done-skill-cases";

const root = fileURLToPath(new URL("../..", import.meta.url));
const skill = readFileSync(`${root}/skills/catalog/done/SKILL.md`, "utf8");
const referencesRoot = `${root}/skills/catalog/done/references`;
const references = readdirSync(referencesRoot)
  .filter((name) => name.endsWith(".md"))
  .sort()
  .map(
    (name) =>
      `\n<done-reference name="${name}">\n${readFileSync(`${referencesRoot}/${name}`, "utf8")}\n</done-reference>`
  )
  .join("\n");
const decisionSchema = fileURLToPath(new URL("done-decision.schema.json", import.meta.url));

export function createDoneSkillHarness() {
  return createHarness<DoneSkillEvalCase, string>({
    name: "done-skill-agent",
    run: async ({ input, signal, setArtifact }) => {
      const prompt = renderPrompt(input);
      const output = await runEvalAgent(prompt, signal);

      setArtifact("caseId", input.id);
      setArtifact("runner", process.env.DONE_SKILL_EVAL_RUNNER ?? "codex");
      return {
        output,
        events: [
          { type: "message", role: "user", content: prompt },
          { type: "message", role: "assistant", content: output },
        ],
      };
    },
  });
}

function renderPrompt(testCase: DoneSkillEvalCase): string {
  return `Follow the Done skill below as the authoritative closeout policy.
Do not use tools. Decide from the scenario facts only.

Return exactly one JSON object with this shape:
{
  "status": "blocked" | "continue",
  "outcome": "done" | "done_local" | "landed_cleanup_deferred" | "pr_merge_pending" | "local_only" | "blocked",
  "canonicalDefaultCheckout": "unchanged" | "updated",
  "actions": ["one or more allowed action ids"],
  "explanation": "one concise sentence"
}

Allowed action ids:
${DONE_ACTIONS.join("\n")}

<done-skill>
${skill}${references}
</done-skill>

<scenario>
${testCase.scenario.trim()}
</scenario>`;
}

function runEvalAgent(prompt: string, signal?: AbortSignal): Promise<string> {
  const runner = process.env.DONE_SKILL_EVAL_RUNNER ?? "codex";
  if (runner === "codex") return runCodex(prompt, signal);
  if (runner === "acpx") return runAcpx(prompt, signal);
  return Promise.reject(new Error(`Invalid DONE_SKILL_EVAL_RUNNER: ${runner}`));
}

async function runCodex(prompt: string, signal?: AbortSignal): Promise<string> {
  const directory = mkdtempSync(join(tmpdir(), "done-skill-eval-"));
  const outputFile = join(directory, "decision.json");
  const args = [
    "exec",
    "--sandbox",
    "read-only",
    "--ephemeral",
    "--ignore-user-config",
    "--skip-git-repo-check",
    "--output-schema",
    decisionSchema,
    "--output-last-message",
    outputFile,
    "--color",
    "never",
    "--cd",
    directory,
  ];
  const model = process.env.DONE_SKILL_EVAL_MODEL;
  if (model) args.push("--model", model);
  args.push("-");

  try {
    await runProcess("codex", args, prompt, signal);
    return readFileSync(outputFile, "utf8").trim();
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

function runAcpx(prompt: string, signal?: AbortSignal): Promise<string> {
  const agent = process.env.DONE_SKILL_EVAL_AGENT ?? "codex";
  if (!/^[a-z0-9-]+$/i.test(agent)) {
    return Promise.reject(new Error(`Invalid DONE_SKILL_EVAL_AGENT: ${agent}`));
  }

  const args = [
    "--cwd",
    root,
    "--auth-policy",
    "fail",
    "--deny-all",
    "--non-interactive-permissions",
    "fail",
    "--allowed-tools",
    "",
    "--max-turns",
    "1",
    "--format",
    "quiet",
    "--no-terminal",
    "--timeout",
    process.env.DONE_SKILL_EVAL_TIMEOUT ?? "150",
    agent,
    "exec",
    "--file",
    "-",
  ];

  return runProcess("acpx", args, prompt, signal);
}

function runProcess(
  command: string,
  args: string[],
  prompt: string,
  signal?: AbortSignal
): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd: root,
      stdio: ["pipe", "pipe", "pipe"],
    });
    const stdout: Buffer[] = [];
    const stderr: Buffer[] = [];
    const abort = () => child.kill("SIGTERM");
    const timeoutMs = Number(process.env.DONE_SKILL_EVAL_TIMEOUT ?? "150") * 1_000;
    const timeout = setTimeout(() => child.kill("SIGTERM"), timeoutMs);

    signal?.addEventListener("abort", abort, { once: true });
    child.stdout.on("data", (chunk: Buffer) => stdout.push(chunk));
    child.stderr.on("data", (chunk: Buffer) => stderr.push(chunk));
    child.on("error", reject);
    child.on("close", (code) => {
      clearTimeout(timeout);
      signal?.removeEventListener("abort", abort);
      if (code === 0) resolve(Buffer.concat(stdout).toString("utf8").trim());
      else {
        reject(
          new Error(
            `${command} exited ${code ?? "without a code"}: ${Buffer.concat(stderr).toString("utf8").trim()}`
          )
        );
      }
    });
    child.stdin.end(prompt);
  });
}
