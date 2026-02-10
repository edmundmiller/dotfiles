import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

type ProviderConfig = {
  agent?: "claude" | "codex";
  model?: string;
  jut_bin?: string;
  runner?: string;
  runner_bin?: string;
  runner_timeout_ms?: number;
  claude_bin?: string;
  claude_runner?: string;
  codex_bin?: string;
  codex_runner?: string;
  auth_mode?: "auto" | "local" | "api";
  min_claude_version?: string;
  min_codex_version?: string;
  keep_fixtures?: boolean;
  allowed_tools?: string[];
};

type PromptfooContext = {
  vars?: Record<string, unknown>;
};

type CommandTrace = {
  command: string;
  failed: boolean;
};

type ResultMeta = {
  text: string;
  subtype: string | null;
  isError: boolean;
  costUsd: number | null;
  turns: number | null;
  durationMs: number | null;
  error: string | null;
};

const DEFAULT_ALLOWED_TOOLS = [
  "Bash",
  "Read",
  "Edit",
  "Write",
  "Glob",
  "Grep",
  "LS",
  "MultiEdit",
  "TodoWrite",
];

const BASH_TOOL_NAME = "Bash";
const DEFAULT_RUNNER_TIMEOUT_MS = 180_000;
const DEFAULT_MIN_CLAUDE_VERSION = "1.0.88";
const DEFAULT_MIN_CODEX_VERSION = "0.99.0";

function parsePositiveInt(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return Math.floor(value);
  }
  if (typeof value !== "string") return null;
  const parsed = Number.parseInt(value.trim(), 10);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function resolveRunnerTimeoutMs(config: ProviderConfig): number {
  return (
    parsePositiveInt(process.env.JUT_EVAL_RUNNER_TIMEOUT_MS) ??
    parsePositiveInt(config.runner_timeout_ms) ??
    DEFAULT_RUNNER_TIMEOUT_MS
  );
}

function parseJson(input: string): unknown {
  try {
    return JSON.parse(input);
  } catch {
    return null;
  }
}

function scriptDir(): string {
  return path.dirname(fileURLToPath(import.meta.url));
}

function evalDir(): string {
  let dir = scriptDir();
  for (let i = 0; i < 6; i++) {
    if (fs.existsSync(path.join(dir, "setup-fixture.sh"))) return dir;
    dir = path.resolve(dir, "..");
  }
  throw new Error("Could not locate eval directory containing setup-fixture.sh");
}

function fallbackJutRoot(): string {
  return path.resolve(evalDir(), "../..");
}

function toMessage(error: unknown): string {
  if (error instanceof Error) {
    const maybeStdErr = (error as { stderr?: string | Buffer }).stderr;
    const stdErrText =
      typeof maybeStdErr === "string"
        ? maybeStdErr.trim()
        : Buffer.isBuffer(maybeStdErr)
          ? maybeStdErr.toString("utf8").trim()
          : "";
    return stdErrText ? `${error.message}: ${stdErrText}` : error.message;
  }
  return String(error);
}

function toStdout(error: unknown): string {
  if (!(error instanceof Error)) return "";
  const s = (error as { stdout?: string | Buffer }).stdout;
  return typeof s === "string" ? s : Buffer.isBuffer(s) ? s.toString("utf8") : "";
}

function toStderr(error: unknown): string {
  if (!(error instanceof Error)) return "";
  const s = (error as { stderr?: string | Buffer }).stderr;
  return typeof s === "string" ? s : Buffer.isBuffer(s) ? s.toString("utf8") : "";
}

function wasTimeout(error: unknown): boolean {
  if (!(error instanceof Error)) return false;
  const e = error as NodeJS.ErrnoException & { killed?: boolean; signal?: string | null };
  return e.code === "ETIMEDOUT" || (e.killed === true && e.signal === "SIGTERM");
}

function asRecord(v: unknown): Record<string, unknown> | null {
  return v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : null;
}
function asString(v: unknown): string | null {
  return typeof v === "string" ? v : null;
}
function asNumber(v: unknown): number | null {
  return typeof v === "number" && Number.isFinite(v) ? v : null;
}
function asBoolean(v: unknown): boolean | null {
  return typeof v === "boolean" ? v : null;
}

// ─── JSONL Parsing ──────────────────────────────────────────────

function parseJsonLines(output: string): unknown[] {
  const events: unknown[] = [];
  for (const line of output.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed.startsWith("{") || !trimmed.endsWith("}")) continue;
    const parsed = parseJson(trimmed);
    if (parsed) events.push(parsed);
  }
  return events;
}

function pushCommand(traces: CommandTrace[], command: string, failed: boolean): void {
  const normalized = command.trim();
  if (!normalized) return;
  const prev = traces[traces.length - 1];
  if (prev?.command === normalized && prev.failed === failed) return;
  traces.push({ command: normalized, failed });
}

function collectBashCommands(
  value: unknown,
  traces: CommandTrace[],
  inBash = false,
  failed = false
): void {
  if (Array.isArray(value)) {
    for (const item of value) collectBashCommands(item, traces, inBash, failed);
    return;
  }
  const record = asRecord(value);
  if (!record) return;

  const type = asString(record.type);
  const name = asString(record.name);
  const toolName = asString(record.tool_name);
  const nextInBash =
    inBash ||
    name === BASH_TOOL_NAME ||
    toolName === BASH_TOOL_NAME ||
    (type === "tool_use" && name === BASH_TOOL_NAME);

  const isFailed =
    failed ||
    asBoolean(record.failed) === true ||
    asBoolean(record.is_error) === true ||
    asBoolean(record.success) === false ||
    (!!record.error && record.error !== false);

  const maybeCommand = asString(record.command);
  if (nextInBash && maybeCommand) pushCommand(traces, maybeCommand, isFailed);

  for (const nested of Object.values(record)) {
    collectBashCommands(nested, traces, nextInBash, isFailed);
  }
}

function collectCodexCommand(value: unknown, traces: CommandTrace[]): void {
  const record = asRecord(value);
  if (!record || asString(record.type) !== "item.completed") return;
  const item = asRecord(record.item);
  if (!item || asString(item.type) !== "command_execution") return;
  const command = asString(item.command);
  if (!command) return;
  const exitCode = asNumber(item.exit_code);
  const status = asString(item.status);
  const failed = (exitCode !== null && exitCode !== 0) || status === "failed";
  pushCommand(traces, command, failed);
}

function extractCommandTrace(events: unknown[]): CommandTrace[] {
  const traces: CommandTrace[] = [];
  for (const event of events) {
    collectBashCommands(event, traces);
    collectCodexCommand(event, traces);
  }
  return traces;
}

function textFromContent(value: unknown): string {
  if (!Array.isArray(value)) return "";
  return value
    .filter(
      (block): block is { type: "text"; text: string } =>
        asRecord(block)?.type === "text" &&
        typeof (block as Record<string, unknown>).text === "string"
    )
    .map((b) => b.text)
    .join("\n")
    .trim();
}

function extractResultMeta(events: unknown[]): ResultMeta {
  let text = "";
  let subtype: string | null = null;
  let isError = false;
  let costUsd: number | null = null;
  let turns: number | null = null;
  let durationMs: number | null = null;
  let error: string | null = null;
  let lastAssistantText = "";
  let codexTurnCount = 0;

  for (const event of events) {
    const record = asRecord(event);
    if (!record) continue;
    const recordType = asString(record.type);

    // Claude assistant messages
    const messageRecord = asRecord(record.message);
    if (recordType === "assistant" && messageRecord) {
      const t = textFromContent(messageRecord.content);
      if (t) lastAssistantText = t;
    }

    // Codex agent messages
    const codexItem = asRecord(record.item);
    if (
      recordType === "item.completed" &&
      codexItem &&
      asString(codexItem.type) === "agent_message"
    ) {
      const t = asString(codexItem.text);
      if (t?.trim()) lastAssistantText = t.trim();
    }

    if (recordType === "turn.completed") codexTurnCount++;

    const looksLikeResult =
      recordType === "result" ||
      "result" in record ||
      "subtype" in record ||
      "num_turns" in record ||
      "duration_ms" in record;
    if (!looksLikeResult) continue;

    const nextText = asString(record.result);
    const nextSubtype = asString(record.subtype);
    const nextIsError = asBoolean(record.is_error);
    const nextError = asString(record.error);
    if (nextText !== null) text = nextText;
    if (nextSubtype !== null) subtype = nextSubtype;
    if (nextIsError !== null) isError = nextIsError;
    if (nextError?.trim()) error = nextError;

    costUsd = asNumber(record.total_cost_usd) ?? costUsd;
    turns = asNumber(record.num_turns) ?? turns;
    durationMs = asNumber(record.duration_ms) ?? durationMs;
  }

  if (turns === null && codexTurnCount > 0) turns = codexTurnCount;
  if (!text && lastAssistantText) text = lastAssistantText;

  return { text, subtype, isError, costUsd, turns, durationMs, error };
}

// ─── Environment ────────────────────────────────────────────────

function stringEnv(overrides?: Record<string, string>): Record<string, string> {
  const entries = Object.entries(process.env).filter(
    (entry): entry is [string, string] => typeof entry[1] === "string"
  );
  return { ...Object.fromEntries(entries), ...overrides };
}

function withJutOnPath(env: Record<string, string>, jutBin: string): Record<string, string> {
  const jutDir = path.dirname(jutBin);
  const existingPath = env.PATH ?? "";
  return {
    ...env,
    PATH: existingPath ? `${jutDir}${path.delimiter}${existingPath}` : jutDir,
    JUT_BIN: jutBin,
  };
}

function resolvePathInEvalDir(candidatePath: string): string {
  return path.isAbsolute(candidatePath) ? candidatePath : path.resolve(evalDir(), candidatePath);
}

function buildPolicyPrompt(): string {
  return [
    "Use jut commands instead of raw jj commands for mutations.",
    "Use `jut status --json` when checking workspace state.",
    "For mutation commands (`jut commit`, `jut squash`, `jut rub`, `jut push`, `jut pull`, etc.), include `--json --status-after`.",
    "Use raw `jj` only for interactive commands (split, resolve, diffedit, edit, rebase) that jut does not wrap.",
    "Avoid routine `--help` probes before mutations; use the skill's canonical command patterns first.",
    "Never run `jut status` after a mutation that used `--status-after`.",
  ].join("\n");
}

// ─── Provider ───────────────────────────────────────────────────

export default class JutIntegrationProvider {
  private readonly providerId: string;
  private readonly config: ProviderConfig;

  constructor(options?: { id?: string; config?: ProviderConfig }) {
    this.providerId = options?.id ?? "jut-integration";
    this.config = options?.config ?? {};
  }

  id(): string {
    return this.providerId;
  }

  private createFixture(jutBin: string): string {
    const fixtureDir = execFileSync("bash", [path.join(evalDir(), "setup-fixture.sh")], {
      cwd: evalDir(),
      encoding: "utf8",
      env: stringEnv({
        JUT_EVAL_JUT_BIN: jutBin,
        JUT_EVAL_KEEP_FIXTURES: this.config.keep_fixtures ? "1" : "0",
      }),
    }).trim();

    if (!fixtureDir) throw new Error("setup-fixture.sh did not return a fixture path");
    return fixtureDir;
  }

  private runSetupCommands(
    rawSetupCommands: unknown,
    fixtureDir: string,
    env: Record<string, string>
  ): void {
    if (typeof rawSetupCommands !== "string" || !rawSetupCommands.trim()) return;
    try {
      execFileSync("bash", ["-euo", "pipefail", "-c", rawSetupCommands], {
        cwd: fixtureDir,
        env,
        stdio: "pipe",
      });
    } catch (error) {
      throw new Error(`Failed setup_commands: ${toMessage(error)}`);
    }
  }

  async callApi(prompt: string, context?: PromptfooContext): Promise<{ output: string }> {
    const jutRoot = process.env.JUT_EVAL_JUT_ROOT ?? fallbackJutRoot();
    const jutBin =
      process.env.JUT_EVAL_JUT_BIN ?? this.config.jut_bin ?? path.join(jutRoot, "target/debug/jut");
    const agent =
      (process.env.JUT_EVAL_AGENT ?? this.config.agent ?? "claude") === "codex"
        ? "codex"
        : "claude";
    const agentLabel = agent === "codex" ? "Codex" : "Claude";

    const runnerBin =
      process.env.JUT_EVAL_RUNNER_BIN ??
      (agent === "codex"
        ? (process.env.JUT_EVAL_CODEX_BIN ??
          this.config.runner_bin ??
          this.config.codex_bin ??
          "codex")
        : (process.env.JUT_EVAL_CLAUDE_BIN ??
          this.config.runner_bin ??
          this.config.claude_bin ??
          "claude"));

    const runnerScript = resolvePathInEvalDir(
      process.env.JUT_EVAL_RUNNER ??
        this.config.runner ??
        (agent === "codex"
          ? (this.config.codex_runner ?? "providers/codex-local.sh")
          : (this.config.claude_runner ?? "providers/claude-local.sh"))
    );

    const authMode = this.config.auth_mode ?? process.env.JUT_EVAL_AUTH_MODE ?? "auto";
    const model =
      process.env.JUT_EVAL_MODEL ??
      this.config.model ??
      (agent === "codex" ? "gpt-5-codex" : "claude-sonnet-4-5-20250929");
    const allowedTools = this.config.allowed_tools ?? DEFAULT_ALLOWED_TOOLS;
    const runnerTimeoutMs = resolveRunnerTimeoutMs(this.config);
    const minRunnerVersion =
      agent === "codex"
        ? (process.env.JUT_EVAL_MIN_CODEX_VERSION ??
          this.config.min_codex_version ??
          DEFAULT_MIN_CODEX_VERSION)
        : (process.env.JUT_EVAL_MIN_CLAUDE_VERSION ??
          this.config.min_claude_version ??
          DEFAULT_MIN_CLAUDE_VERSION);

    let fixtureDir: string | null = null;
    const commands: CommandTrace[] = [];
    let resultText = "";
    let resultSubtype: string | null = null;
    let resultIsError = false;
    let resultCostUsd: number | null = null;
    let resultTurns: number | null = null;
    let resultDurationMs: number | null = null;
    let resultErrorMessage: string | null = null;

    try {
      if (!fs.existsSync(runnerScript)) {
        throw new Error(`${agentLabel} runner script not found: ${runnerScript}`);
      }

      fixtureDir = this.createFixture(jutBin);
      const env = withJutOnPath(stringEnv(), jutBin);

      this.runSetupCommands(context?.vars?.setup_commands, fixtureDir, env);

      const taskPrompt =
        typeof context?.vars?.prompt === "string" && context.vars.prompt.trim()
          ? context.vars.prompt
          : prompt;

      let rawAgentOutput = "";
      let cliRunError: string | null = null;

      try {
        rawAgentOutput = execFileSync("bash", [runnerScript], {
          cwd: fixtureDir,
          encoding: "utf8",
          stdio: ["ignore", "pipe", "pipe"],
          timeout: runnerTimeoutMs,
          env: {
            ...env,
            JUT_EVAL_AGENT: agent,
            JUT_EVAL_RUNNER_BIN: runnerBin,
            JUT_EVAL_CLAUDE_BIN:
              agent === "claude" ? runnerBin : (process.env.JUT_EVAL_CLAUDE_BIN ?? "claude"),
            JUT_EVAL_CODEX_BIN:
              agent === "codex" ? runnerBin : (process.env.JUT_EVAL_CODEX_BIN ?? "codex"),
            JUT_EVAL_MODEL: model,
            JUT_EVAL_AUTH_MODE: authMode,
            JUT_EVAL_PROMPT: taskPrompt,
            JUT_EVAL_ALLOWED_TOOLS: allowedTools.join(","),
            JUT_EVAL_PERMISSION_MODE: "bypassPermissions",
            JUT_EVAL_APPEND_SYSTEM_PROMPT: buildPolicyPrompt(),
            JUT_EVAL_MIN_RUNNER_VERSION: minRunnerVersion,
          },
        });
      } catch (error) {
        const stdout = toStdout(error);
        const stderr = toStderr(error);
        rawAgentOutput = `${stdout}${stdout && stderr ? "\n" : ""}${stderr}`;
        cliRunError = wasTimeout(error)
          ? `${agentLabel} runner timed out after ${runnerTimeoutMs}ms.`
          : toMessage(error);
      }

      const events = parseJsonLines(rawAgentOutput);
      commands.push(...extractCommandTrace(events));

      const meta = extractResultMeta(events);
      resultText = meta.text;
      resultSubtype = meta.subtype;
      resultIsError = meta.isError;
      resultCostUsd = meta.costUsd;
      resultTurns = meta.turns;
      resultDurationMs = meta.durationMs;
      resultErrorMessage = meta.error;

      if (cliRunError) {
        resultIsError = true;
        resultSubtype = resultSubtype ?? "error";
        resultErrorMessage = resultErrorMessage
          ? `${resultErrorMessage}\n${cliRunError}`
          : cliRunError;
      }

      // Capture repo state after agent finishes
      let repoState: unknown = null;
      let repoStateError: string | null = null;
      try {
        repoState = JSON.parse(
          execFileSync(jutBin, ["-C", fixtureDir, "status", "--json"], {
            encoding: "utf8",
            env,
          })
        );
      } catch (error) {
        repoStateError = toMessage(error);
      }

      return {
        output: JSON.stringify({
          fixtureDir: this.config.keep_fixtures ? fixtureDir : null,
          commands,
          result: resultText,
          resultMeta: {
            subtype: resultSubtype,
            isError: resultIsError,
            totalCostUsd: resultCostUsd,
            numTurns: resultTurns,
            durationMs: resultDurationMs,
            error: resultErrorMessage,
          },
          repoState,
          repoStateError,
        }),
      };
    } catch (error) {
      return {
        output: JSON.stringify({
          fixtureDir: this.config.keep_fixtures ? (fixtureDir ?? null) : null,
          commands,
          error: toMessage(error),
        }),
      };
    } finally {
      if (!this.config.keep_fixtures && fixtureDir) {
        try {
          fs.rmSync(fixtureDir, { recursive: true, force: true });
        } catch {
          // best-effort cleanup
        }
      }
    }
  }
}
