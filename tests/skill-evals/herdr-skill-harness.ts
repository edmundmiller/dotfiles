import {
  chmodSync,
  copyFileSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { spawn, spawnSync } from "node:child_process";
import { homedir, tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { createHarness } from "vitest-evals";

import { renderArmContext, type ArmId } from "./herdr-skill-arms";
import type { HerdrSkillEvalCase } from "./herdr-skill-cases";
import type { HerdrRunOutput } from "./herdr-skill-scorer";

const decisionSchema = fileURLToPath(new URL("herdr-decision.schema.json", import.meta.url));

const shimPath = join(dirname(fileURLToPath(import.meta.url)), "herdr-shim.sh");
const helpCorpusPath = join(dirname(fileURLToPath(import.meta.url)), "herdr-help-corpus.json");
const repoRoot = fileURLToPath(new URL("../..", import.meta.url));

export type HerdrEvalInput = HerdrSkillEvalCase & { arm: ArmId };

export function createHerdrSkillHarness() {
  return createHarness<HerdrEvalInput, string>({
    name: "herdr-skill-agent",
    run: async ({ input, signal, setArtifact }) => {
      const prompt = renderPrompt(input);
      const runner = process.env.HERDR_SKILL_EVAL_RUNNER ?? "claude";
      let output: string;
      let observedHelpCalls: number | undefined;
      const result =
        runner === "codex" ? await runCodex(prompt, signal) : await runClaude(prompt, signal);
      output = result.raw;
      observedHelpCalls = result.observedHelpCalls;
      if (observedHelpCalls !== undefined) {
        setArtifact("observedHelpCalls", String(observedHelpCalls));
        // The shim log is ground truth; the model's self-report is not.
        output = JSON.stringify({
          ...(JSON.parse(output) as Record<string, unknown>),
          helpInvocations: observedHelpCalls,
        });
      }

      setArtifact("caseId", input.id);
      setArtifact("arm", input.arm);
      setArtifact("taskClass", input.taskClass);
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

/**
 * Every arm gets identical instructions and identical tool access. Only the
 * context block differs, which is the single variable under test.
 */
function renderPrompt(input: HerdrEvalInput): string {
  return `${renderArmContext(input.arm)}

Answer the task below. You may run read-only \`herdr --help\` commands to
discover the CLI. Do not mutate the live session: no splits, no agent starts,
no sends. Report the sequence you *would* run.

Return exactly one JSON object:
{
  "plan": "one command per line",
  "explanation": "why this is correct",
  "helpInvocations": <how many herdr --help commands you ran>
}

<task>
${input.task.trim()}
</task>`;
}

export function parseHerdrOutput(raw: string): HerdrRunOutput {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch (error) {
    throw new Error(`herdr eval returned non-JSON output: ${raw.slice(0, 200)}`, { cause: error });
  }
  if (typeof parsed !== "object" || parsed === null) {
    throw new Error(`herdr eval returned a non-object payload: ${raw.slice(0, 200)}`);
  }
  const record = parsed as Record<string, unknown>;
  const plan = record.plan;
  const explanation = record.explanation;
  if (typeof plan !== "string" || typeof explanation !== "string") {
    throw new Error(`herdr eval payload missing plan/explanation: ${raw.slice(0, 200)}`);
  }
  const help = record.helpInvocations;
  return {
    plan,
    explanation,
    helpInvocations: typeof help === "number" && Number.isFinite(help) ? help : 0,
  };
}

async function runCodex(
  prompt: string,
  signal?: AbortSignal
): Promise<{ raw: string; observedHelpCalls: number }> {
  const { directory, binDir, shimLog, zdotdir, corpus } = createSandboxDir();
  const outputFile = join(directory, "decision.json");

  const args = [
    "exec",
    // `read-only` sandboxes the filesystem; it does NOT stop herdr from
    // mutating live session state over IPC. The shim is what actually
    // enforces that, and it is also where the help count is measured.
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
  const model = process.env.HERDR_SKILL_EVAL_MODEL;
  if (model) args.push("--model", model);
  args.push("-");

  try {
    await runProcess("codex", args, prompt, signal, directory, {
      ...shimEnv(binDir, shimLog, zdotdir, corpus),
    });
    return {
      raw: readFileSync(outputFile, "utf8").trim(),
      observedHelpCalls: countHelpCalls(readFileSync(shimLog, "utf8")),
    };
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

/**
 * `claude -p` backend, used when codex is unavailable. It has no
 * `--output-schema`, so the JSON contract is enforced by the prompt and
 * validated by `parseHerdrOutput`.
 *
 * Isolation is enforced at three levels, because the weaker two are not
 * enough on their own:
 *
 *   1. Empty temp cwd and `--setting-sources ''`, so no project/user CLAUDE.md,
 *      settings, or installed skills are inherited.
 *   2. `--tools Bash`, removing the native Read/Glob/Grep tools.
 *   3. An OS sandbox denying reads of the dotfiles repo and the installed
 *      skill directories. Levels 1-2 do NOT stop `cat /abs/path/SKILL.md` --
 *      verified: without this, the helpOnly arm can read the very skill it is
 *      supposed to lack, silently contaminating the comparison.
 */
async function runClaude(
  prompt: string,
  signal?: AbortSignal
): Promise<{ raw: string; observedHelpCalls: number }> {
  const { directory, binDir, shimLog, zdotdir, corpus } = createSandboxDir();

  const claudeArgs = [
    "-p",
    "--output-format",
    "text",
    // Availability, not just pre-approval: no Read/Glob/Grep into the repo.
    "--tools",
    "Bash",
    "--allowed-tools",
    "Bash",
    "--setting-sources",
    "",
    "--strict-mcp-config",
  ];
  const model = process.env.HERDR_SKILL_EVAL_MODEL;
  if (model) claudeArgs.push("--model", model);

  const { command, args } = wrapInSandbox("claude", claudeArgs, directory);

  try {
    const stdout = await captureProcess(command, args, prompt, signal, directory, {
      // Shim first: mutating calls are refused, every argv is recorded.
      ...shimEnv(binDir, shimLog, zdotdir, corpus),
    });
    const match = stdout.match(/\{[\s\S]*\}/);
    if (!match) {
      throw new Error(`claude returned no JSON object: ${stdout.slice(0, 200)}`);
    }
    return {
      raw: match[0],
      observedHelpCalls: countHelpCalls(readFileSync(shimLog, "utf8")),
    };
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

/** Measured from the shim log, never from the model's self-report. */
export function countHelpCalls(log: string): number {
  return log
    .split("\n")
    .filter((line) => line.trim() !== "")
    .filter((line) => /(^|\s)(--help|-h)(\s|$)/.test(line) || /^\s*help(\s|$)/.test(line)).length;
}

/**
 * Denies reads of the skill sources so no arm can `cat` its way to the context
 * another arm was given, and denies the herdr IPC socket so no command can
 * reach the live session.
 *
 * The socket denial is what makes interception fail-closed. Intercepting by
 * name -- PATH entry or shell function -- is defeated by an absolute path, and
 * `/etc/profiles/.../herdr pane list` was verified to reach the real session
 * and dump live pane data. Denying the binary instead is no better: it falls
 * to `cp herdr /tmp/evil`. The socket is the actual capability, so a copied
 * binary is deliberately allowed to run and still fails. See
 * herdr-interception.test.ts for the bypass regressions.
 */
function wrapInSandbox(
  command: string,
  args: string[],
  directory: string
): { command: string; args: string[] } {
  if (process.env.HERDR_SKILL_EVAL_NO_SANDBOX === "1") return { command, args };

  if (process.platform !== "darwin") {
    throw new Error(
      "herdr skill evals need an OS sandbox to keep arms isolated; " +
        "only macOS sandbox-exec is wired up. Set HERDR_SKILL_EVAL_NO_SANDBOX=1 " +
        "to run anyway and treat the results as contaminated."
    );
  }

  const denied = [repoRoot, join(homedir(), ".agents"), join(homedir(), ".claude")];
  // Deny the IPC socket directory, not the herdr binary. Denying the binary is
  // not fail-closed -- it is defeated by `cp` to another path, a second
  // installation, or any other client that speaks the protocol. The socket is
  // the actual capability, and without it every route to the live session
  // fails regardless of which executable is used.
  const herdrRuntime = join(homedir(), ".config", "herdr");
  const policy = [
    "(version 1)",
    "(allow default)",
    "(deny file-read*",
    ...denied.map((d) => `  (subpath ${JSON.stringify(d)})`),
    ")",
    // network* covers AF_UNIX connect on macOS; file-read*/write* stops the
    // socket being reached as a filesystem path.
    `(deny network* (subpath ${JSON.stringify(herdrRuntime)}))`,
    `(deny file-read* file-write* (subpath ${JSON.stringify(herdrRuntime)}))`,
  ].join("\n");
  const policyFile = join(directory, "eval-sandbox.sb");
  writeFileSync(policyFile, `${policy}\n`);

  return { command: "sandbox-exec", args: ["-f", policyFile, command, ...args] };
}

/**
 * Builds the per-run sandbox directory: the recording shim, its audit log, and
 * a ZDOTDIR whose rc files define a `herdr` shell function.
 *
 * The function matters. Claude's Bash tool runs a LOGIN shell, and
 * /etc/zprofile rebuilds PATH from scratch -- which put the real herdr ahead of
 * a PATH-only shim and bypassed it entirely, silently undercounting help calls
 * and leaving the live session unprotected. A function defined in every rc file
 * survives that rebuild and wins over PATH lookup.
 */
function createSandboxDir(): {
  directory: string;
  binDir: string;
  shimLog: string;
  zdotdir: string;
  corpus: string;
} {
  const directory = mkdtempSync(join(tmpdir(), "herdr-skill-eval-"));
  const binDir = join(directory, "bin");
  const zdotdir = join(directory, "zdot");
  const shimLog = join(directory, "herdr-calls.log");
  mkdirSync(binDir);
  mkdirSync(zdotdir);

  const shimBin = join(binDir, "herdr");
  copyFileSync(shimPath, shimBin);
  chmodSync(shimBin, 0o755);
  writeFileSync(shimLog, "");
  const corpus = sandboxCorpus(directory);

  const rc = [
    `herdr() { command ${JSON.stringify(shimBin)} "$@"; }`,
    `export HERDR_SHIM_LOG=${JSON.stringify(shimLog)}`,
    `export HERDR_HELP_CORPUS=${JSON.stringify(corpus)}`,
    "",
  ].join("\n");
  for (const file of [".zshenv", ".zprofile", ".zshrc"]) {
    writeFileSync(join(zdotdir, file), rc);
  }

  return { directory, binDir, shimLog, zdotdir, corpus };
}

function shimEnv(
  binDir: string,
  shimLog: string,
  zdotdir: string,
  corpus: string
): Record<string, string> {
  return {
    PATH: `${binDir}:${process.env.PATH ?? ""}`,
    ZDOTDIR: zdotdir,
    HERDR_SHIM_LOG: shimLog,
    HERDR_HELP_CORPUS: corpus,
  };
}

function sandboxCorpus(directory: string): string {
  // Must live outside repoRoot: the sandbox denies reading the repo, so the
  // shim cannot replay help from the checked-in copy.
  const dest = join(directory, "herdr-help-corpus.json");
  copyFileSync(helpCorpusPath, dest);
  return dest;
}

function captureProcess(
  command: string,
  args: string[],
  prompt: string,
  signal?: AbortSignal,
  cwd?: string,
  extraEnv?: Record<string, string>
): Promise<string> {
  const { promise, resolve, reject } = Promise.withResolvers<string>();
  const child = spawn(command, args, {
    stdio: ["pipe", "pipe", "pipe"],
    signal,
    cwd,
    env: extraEnv ? { ...process.env, ...extraEnv } : process.env,
  });
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
    else reject(new Error(`${command} exited ${code}: ${stderr.slice(-400)}`));
  });
  child.stdin.end(prompt);
  return promise;
}

function runProcess(
  command: string,
  args: string[],
  prompt: string,
  signal?: AbortSignal,
  cwd?: string,
  extraEnv?: Record<string, string>
): Promise<void> {
  const { promise, resolve, reject } = Promise.withResolvers<void>();
  const child = spawn(command, args, {
    stdio: ["pipe", "pipe", "pipe"],
    signal,
    cwd,
    env: extraEnv ? { ...process.env, ...extraEnv } : process.env,
  });
  let stderr = "";
  child.stderr.on("data", (chunk) => {
    stderr += String(chunk);
  });
  child.on("error", reject);
  child.on("close", (code) => {
    if (code === 0) resolve();
    else reject(new Error(`${command} exited ${code}: ${stderr.slice(-400)}`));
  });
  child.stdin.end(prompt);
  return promise;
}
