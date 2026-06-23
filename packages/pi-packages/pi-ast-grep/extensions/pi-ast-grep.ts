import { execFile } from "node:child_process";
import { access, constants, mkdtemp, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { tmpdir } from "node:os";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const MAX_BYTES = 50 * 1024;
const MAX_LINES = 2_000;
const DEFAULT_TIMEOUT_MS = 30_000;

const EXTENSION_DIR = dirname(fileURLToPath(import.meta.url));
const PACKAGE_ROOT = dirname(EXTENSION_DIR);

const OUTLINE_VIEWS = new Set(["auto", "names", "signatures", "digest", "expanded"]);
const OUTLINE_ITEMS = new Set(["auto", "structure", "exports", "imports", "all"]);
const JSON_STYLES = new Set(["none", "pretty", "stream", "compact"]);
const STRICTNESS_VALUES = new Set(["cst", "smart", "ast", "relaxed", "signature", "template"]);
const HEADING_VALUES = new Set(["auto", "always", "never"]);
const REWRITE_MODES = new Set(["preview", "apply"]);
const NO_IGNORE_VALUES = new Set(["hidden", "dot", "exclude", "global", "parent", "vcs"]);

const pathArray = Type.Optional(
  Type.Array(Type.String({ description: "File or directory path. Leading @ is stripped." }))
);
const globArray = Type.Optional(
  Type.Array(Type.String({ description: "Include/exclude glob. Prefix with ! to exclude." }))
);
const noIgnoreArray = Type.Optional(
  Type.Array(
    Type.String({
      description: "Ignore source to bypass: hidden, dot, exclude, global, parent, or vcs.",
    })
  )
);

const outlineParams = Type.Object({
  paths: pathArray,
  lang: Type.Optional(
    Type.String({ description: "Input language. Usually omitted so ast-grep infers from path." })
  ),
  view: Type.Optional(
    Type.String({
      description: "Text view: auto, names, signatures, digest, or expanded. Default auto.",
    })
  ),
  items: Type.Optional(
    Type.String({
      description: "Top-level items: auto, structure, exports, imports, or all. Default auto.",
    })
  ),
  types: Type.Optional(
    Type.Array(Type.String({ description: "Symbol types to keep, e.g. class, function, enum." }))
  ),
  match: Type.Optional(
    Type.String({ description: "Regex matched against item names/signatures/source lines." })
  ),
  pubMembers: Type.Optional(
    Type.Boolean({ description: "Only display public members in member views." })
  ),
  json: Type.Optional(
    Type.String({
      description: "JSON output style: none, pretty, stream, or compact. Default none.",
    })
  ),
  config: Type.Optional(
    Type.String({ description: "Path to ast-grep root config. Default sgconfig.yml." })
  ),
  outlineRules: Type.Optional(
    Type.Array(Type.String({ description: "Extra outline extractor YAML file." }))
  ),
  noDefaultOutlineRules: Type.Optional(
    Type.Boolean({ description: "Disable bundled outline extractor rules." })
  ),
  follow: Type.Optional(Type.Boolean({ description: "Follow symlinks." })),
  globs: globArray,
  noIgnore: noIgnoreArray,
  threads: Type.Optional(
    Type.Number({
      minimum: 0,
      description: "Approximate thread count. Default 0 lets ast-grep choose.",
    })
  ),
  timeoutSeconds: Type.Optional(
    Type.Number({ minimum: 1, maximum: 600, description: "Command timeout. Default 30 seconds." })
  ),
});

const searchParams = Type.Object({
  pattern: Type.Optional(
    Type.String({ description: "Code pattern to match, e.g. 'console.log($$$ARGS)'." })
  ),
  kind: Type.Optional(Type.String({ description: "AST kind or ESQuery-style selector to match." })),
  lang: Type.Optional(
    Type.String({ description: "Pattern language, e.g. ts, javascript, rust, python." })
  ),
  selector: Type.Optional(
    Type.String({ description: "AST kind to select from a larger pattern context." })
  ),
  strictness: Type.Optional(
    Type.String({ description: "cst, smart, ast, relaxed, signature, or template." })
  ),
  paths: pathArray,
  json: Type.Optional(
    Type.String({
      description: "JSON output style: none, pretty, stream, or compact. Default none.",
    })
  ),
  filesWithMatches: Type.Optional(
    Type.Boolean({ description: "Only print paths with at least one match." })
  ),
  before: Type.Optional(
    Type.Number({ minimum: 0, description: "Show N lines before each match." })
  ),
  after: Type.Optional(Type.Number({ minimum: 0, description: "Show N lines after each match." })),
  context: Type.Optional(
    Type.Number({ minimum: 0, description: "Show N lines around each match." })
  ),
  heading: Type.Optional(
    Type.String({
      description: "Heading mode: auto, always, or never. Default never for agent output.",
    })
  ),
  follow: Type.Optional(Type.Boolean({ description: "Follow symlinks." })),
  globs: globArray,
  noIgnore: noIgnoreArray,
  threads: Type.Optional(
    Type.Number({
      minimum: 0,
      description: "Approximate thread count. Default 0 lets ast-grep choose.",
    })
  ),
  timeoutSeconds: Type.Optional(
    Type.Number({ minimum: 1, maximum: 600, description: "Command timeout. Default 30 seconds." })
  ),
});

const rewriteParams = Type.Object({
  pattern: Type.Optional(
    Type.String({ description: "Code pattern to rewrite, e.g. 'console.log($$$ARGS)'." })
  ),
  kind: Type.Optional(
    Type.String({ description: "AST kind or ESQuery-style selector to rewrite." })
  ),
  rewrite: Type.String({
    description:
      "Replacement string for the matched AST node. Metavars from pattern are supported.",
  }),
  mode: Type.Optional(
    Type.String({
      description:
        "Rewrite mode: preview or apply. Default preview prints the diff; apply mutates files with --update-all.",
    })
  ),
  lang: Type.Optional(
    Type.String({ description: "Pattern language, e.g. ts, javascript, rust, python." })
  ),
  selector: Type.Optional(
    Type.String({ description: "AST kind to select from a larger pattern context." })
  ),
  strictness: Type.Optional(
    Type.String({ description: "cst, smart, ast, relaxed, signature, or template." })
  ),
  config: Type.Optional(
    Type.String({ description: "Path to ast-grep root config. Default sgconfig.yml." })
  ),
  paths: pathArray,
  follow: Type.Optional(Type.Boolean({ description: "Follow symlinks." })),
  globs: globArray,
  noIgnore: noIgnoreArray,
  threads: Type.Optional(
    Type.Number({
      minimum: 0,
      description: "Approximate thread count. Default 0 lets ast-grep choose.",
    })
  ),
  timeoutSeconds: Type.Optional(
    Type.Number({ minimum: 1, maximum: 600, description: "Command timeout. Default 30 seconds." })
  ),
});

const scanParams = Type.Object({
  paths: pathArray,
  ruleFile: Type.Optional(
    Type.String({ description: "Single ast-grep rule YAML file to scan with." })
  ),
  inlineRules: Type.Optional(
    Type.String({ description: "Inline rule YAML. Separate multiple rules with --- ." })
  ),
  config: Type.Optional(
    Type.String({ description: "Path to ast-grep root config. Default sgconfig.yml." })
  ),
  filter: Type.Optional(Type.String({ description: "Regex for rule ids to run." })),
  includeMetadata: Type.Optional(
    Type.Boolean({ description: "Include rule metadata in JSON output." })
  ),
  json: Type.Optional(
    Type.String({
      description: "JSON output style: none, pretty, stream, or compact. Default none.",
    })
  ),
  mode: Type.Optional(
    Type.String({
      description:
        "Scan mode: preview or apply. Default preview reports matches/fixes; apply mutates files with --update-all.",
    })
  ),
  maxResults: Type.Optional(
    Type.Number({ minimum: 1, description: "Stop after this many results." })
  ),
  follow: Type.Optional(Type.Boolean({ description: "Follow symlinks." })),
  globs: globArray,
  noIgnore: noIgnoreArray,
  threads: Type.Optional(
    Type.Number({
      minimum: 0,
      description: "Approximate thread count. Default 0 lets ast-grep choose.",
    })
  ),
  timeoutSeconds: Type.Optional(
    Type.Number({ minimum: 1, maximum: 600, description: "Command timeout. Default 30 seconds." })
  ),
});

interface CommandResult {
  stdout: string;
  stderr: string;
  exitCode: number;
}

interface ToolOutputDetails {
  command: string[];
  cwd: string;
  exitCode: number;
  stdoutBytes: number;
  stderrBytes: number;
  fullOutputPath?: string;
  truncation?: {
    truncated: boolean;
    totalLines: number;
    outputLines: number;
    totalBytes: number;
    outputBytes: number;
  };
}

class AstGrepCommandError extends Error {
  result: CommandResult;

  constructor(command: string, args: string[], result: CommandResult) {
    const stderr = result.stderr.trim();
    super(
      `${command} ${args.join(" ")} failed with exit ${result.exitCode}${stderr ? `: ${stderr}` : ""}`
    );
    this.result = result;
  }
}

export default function astGrepExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "ast_grep_outline",
    label: "ast-grep outline",
    description:
      "Map code structure with ast-grep outline. Use before reading large files or directories. Output is truncated to 2,000 lines or 50 KiB.",
    promptSnippet:
      "Map code structure with ast_grep_outline before reading large source files or directories.",
    promptGuidelines: [
      "Use ast_grep_outline before reading large source files when you need symbols, imports, exports, members, or a repo/file skeleton.",
      "Prefer ast_grep_outline with view=names or view=digest for context building; use view=expanded only when you need member signatures.",
    ],
    parameters: outlineParams,
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const args = buildOutlineArgs(params);
      const command = await findAstGrepBinary();
      const result = await runCommand(
        command,
        args,
        ctx.cwd,
        signal,
        timeoutMs(params.timeoutSeconds)
      );
      return formatResult({
        command,
        args,
        cwd: ctx.cwd,
        result,
        emptyText: "No outline entries found.",
      });
    },
  });

  pi.registerTool({
    name: "ast_grep_search",
    label: "ast-grep search",
    description:
      "Read-only structural code search with ast-grep run. Does not rewrite files. Output is truncated to 2,000 lines or 50 KiB.",
    promptSnippet: "Search code structurally with ast_grep_search when rg would be too noisy.",
    promptGuidelines: [
      "Use ast_grep_search for syntax-aware searches such as function calls, imports, class declarations, JSX elements, or AST kinds where rg would return noisy text matches.",
      "ast_grep_search is read-only in this package. For edits, inspect matches first, then use edit/write with exact changes.",
    ],
    parameters: searchParams,
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const args = buildSearchArgs(params);
      const command = await findAstGrepBinary();
      const result = await runCommand(
        command,
        args,
        ctx.cwd,
        signal,
        timeoutMs(params.timeoutSeconds),
        [0, 1]
      );
      return formatResult({ command, args, cwd: ctx.cwd, result, emptyText: "No matches found." });
    },
  });

  pi.registerTool({
    name: "ast_grep_rewrite",
    label: "ast-grep rewrite",
    description:
      "Rewrite code with ast-grep run --rewrite. Defaults to preview diff; mode=apply mutates files with --update-all and returns the resulting git diff when available.",
    promptSnippet:
      "Use ast_grep_rewrite for syntax-aware codemods. Preview first for broad changes; use mode=apply when the rule is narrow and intentional.",
    promptGuidelines: [
      "Use ast_grep_rewrite for AST-aware codemods where edit would be repetitive or text regex would be brittle.",
      "Preview broad rewrites first. Apply directly only when paths/globs and pattern are narrow enough that the result is obvious.",
      "After mode=apply, inspect the returned git diff or run project checks before claiming the rewrite is good.",
    ],
    parameters: rewriteParams,
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const mode = choiceValue(stringParam(params.mode), REWRITE_MODES, "mode", "preview");
      const args = buildRewriteArgs(params, mode);
      const command = await findAstGrepBinary();
      const result = await runCommand(
        command,
        args,
        ctx.cwd,
        signal,
        timeoutMs(params.timeoutSeconds),
        [0, 1]
      );
      if (mode === "apply") {
        const status = await safeGitStatus(ctx.cwd, signal);
        const diff = await safeGitDiff(ctx.cwd, normalizePaths(params.paths), signal);
        const enriched = {
          ...result,
          stdout: [
            result.stdout.trimEnd(),
            status ? `[git status after]\n${status}` : "",
            diff ? `[git diff after]\n${diff}` : "",
          ]
            .filter(Boolean)
            .join("\n\n"),
        };
        return formatResult({
          command,
          args,
          cwd: ctx.cwd,
          result: enriched,
          emptyText: "No rewrite matches found.",
        });
      }
      return formatResult({
        command,
        args,
        cwd: ctx.cwd,
        result,
        emptyText: "No rewrite matches found.",
      });
    },
  });

  pi.registerTool({
    name: "ast_grep_scan",
    label: "ast-grep scan",
    description:
      "Run ast-grep scan for project config, a rule file, or inline rules. Defaults to preview; mode=apply applies rule fixes with --update-all and returns the resulting git diff when available.",
    promptSnippet:
      "Run ast-grep rule/config scans with ast_grep_scan for structural lint/refactor checks. Use mode=apply for trusted rule fixes.",
    promptGuidelines: [
      "Use ast_grep_scan when a structural search needs YAML rules, project sgconfig.yml, or reusable rule filters.",
      "Use ast_grep_scan mode=apply for trusted rule fixes from sgconfig.yml or a narrow rule file; inspect the returned diff afterward.",
    ],
    parameters: scanParams,
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const mode = choiceValue(stringParam(params.mode), REWRITE_MODES, "mode", "preview");
      const args = buildScanArgs(params, mode);
      const command = await findAstGrepBinary();
      const result = await runCommand(
        command,
        args,
        ctx.cwd,
        signal,
        timeoutMs(params.timeoutSeconds),
        [0, 1]
      );
      if (mode === "apply") {
        const status = await safeGitStatus(ctx.cwd, signal);
        const diff = await safeGitDiff(ctx.cwd, normalizePaths(params.paths), signal);
        const enriched = {
          ...result,
          stdout: [
            result.stdout.trimEnd(),
            status ? `[git status after]\n${status}` : "",
            diff ? `[git diff after]\n${diff}` : "",
          ]
            .filter(Boolean)
            .join("\n\n"),
        };
        return formatResult({
          command,
          args,
          cwd: ctx.cwd,
          result: enriched,
          emptyText: "No scan results found.",
        });
      }
      return formatResult({
        command,
        args,
        cwd: ctx.cwd,
        result,
        emptyText: "No scan results found.",
      });
    },
  });

  pi.registerTool({
    name: "ast_grep_doctor",
    label: "ast-grep doctor",
    description: "Verify ast-grep binary resolution, version, and outline command support.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, signal, _onUpdate, ctx) {
      const command = await findAstGrepBinary();
      const version = await runCommand(command, ["--version"], ctx.cwd, signal, 10_000);
      let outlineSupported = true;
      let outlineHelp = "";
      try {
        const help = await runCommand(command, ["outline", "--help"], ctx.cwd, signal, 10_000);
        outlineHelp = help.stdout.trim();
      } catch (error) {
        outlineSupported = false;
        outlineHelp = error instanceof Error ? error.message : String(error);
      }
      const lines = [
        `binary: ${command}`,
        `version: ${version.stdout.trim()}`,
        `outline: ${outlineSupported ? "supported" : "missing"}`,
      ];
      if (!outlineSupported) {
        lines.push(
          "advice: install @ast-grep/cli@0.44.0 or newer; Homebrew ast-grep 0.43.x lacks outline."
        );
      }
      return {
        content: [{ type: "text", text: lines.join("\n") }],
        details: {
          command,
          version: version.stdout.trim(),
          outlineSupported,
          outlineHelpSnippet: outlineHelp.slice(0, 2_000),
        },
      };
    },
  });

  pi.registerCommand("ast-grep-doctor", {
    description: "Verify ast-grep version and outline support",
    handler: async (_args, ctx) => {
      try {
        const command = await findAstGrepBinary();
        const version = await runCommand(command, ["--version"], ctx.cwd, undefined, 10_000);
        await runCommand(command, ["outline", "--help"], ctx.cwd, undefined, 10_000);
        ctx.ui.notify(`ast-grep OK: ${version.stdout.trim()}`, "info");
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
      }
    },
  });
}

function buildOutlineArgs(params: Record<string, unknown>) {
  const args = ["outline", "--color", "never"];
  pushOptional(args, "--lang", stringParam(params.lang));
  pushChoice(args, "--view", stringParam(params.view), OUTLINE_VIEWS, "view");
  pushChoice(args, "--items", stringParam(params.items), OUTLINE_ITEMS, "items");
  const json = choiceValue(stringParam(params.json), JSON_STYLES, "json", "none");
  if (json !== "none") args.push(`--json=${json}`);
  const types = stringArrayParam(params.types);
  if (types.length) args.push("--type", types.join(","));
  pushOptional(args, "--match", stringParam(params.match));
  if (params.pubMembers === true) args.push("--pub-members");
  pushOptional(args, "--config", stringParam(params.config)?.replace(/^@/, ""));
  for (const rule of stringArrayParam(params.outlineRules).map(stripAtPrefix))
    args.push("--outline-rules", rule);
  if (params.noDefaultOutlineRules === true) args.push("--no-default-outline-rules");
  pushSharedArgs(args, params);
  args.push(...normalizePaths(params.paths));
  return args;
}

function buildSearchArgs(params: Record<string, unknown>) {
  const pattern = stringParam(params.pattern);
  const kind = stringParam(params.kind);
  if (!pattern && !kind) throw new Error("ast_grep_search requires pattern or kind");
  if (
    params.filesWithMatches === true &&
    stringParam(params.json) &&
    stringParam(params.json) !== "none"
  ) {
    throw new Error("ast_grep_search cannot combine filesWithMatches with json output");
  }
  const args = ["run", "--color", "never"];
  if (pattern) args.push("--pattern", pattern);
  if (kind) args.push("--kind", kind);
  pushOptional(args, "--selector", stringParam(params.selector));
  pushChoice(args, "--strictness", stringParam(params.strictness), STRICTNESS_VALUES, "strictness");
  pushOptional(args, "--lang", stringParam(params.lang));
  const json = choiceValue(stringParam(params.json), JSON_STYLES, "json", "none");
  if (json !== "none") args.push(`--json=${json}`);
  if (params.filesWithMatches === true) args.push("--files-with-matches");
  const context = numberParam(params.context);
  if (context !== undefined) {
    args.push("--context", String(context));
  } else {
    pushNumber(args, "--before", params.before);
    pushNumber(args, "--after", params.after);
  }
  pushChoice(args, "--heading", stringParam(params.heading) ?? "never", HEADING_VALUES, "heading");
  pushSharedArgs(args, params);
  args.push(...normalizePaths(params.paths));
  return args;
}

function buildRewriteArgs(params: Record<string, unknown>, mode: string) {
  const pattern = stringParam(params.pattern);
  const kind = stringParam(params.kind);
  const rewrite = stringParam(params.rewrite);
  if (!pattern && !kind) throw new Error("ast_grep_rewrite requires pattern or kind");
  if (!rewrite) throw new Error("ast_grep_rewrite requires rewrite");
  const args = ["run", "--color", "never"];
  if (pattern) args.push("--pattern", pattern);
  if (kind) args.push("--kind", kind);
  args.push("--rewrite", rewrite);
  if (mode === "apply") args.push("--update-all");
  pushOptional(args, "--selector", stringParam(params.selector));
  pushChoice(args, "--strictness", stringParam(params.strictness), STRICTNESS_VALUES, "strictness");
  pushOptional(args, "--lang", stringParam(params.lang));
  pushOptional(args, "--config", stringParam(params.config)?.replace(/^@/, ""));
  pushSharedArgs(args, params);
  args.push(...normalizePaths(params.paths));
  return args;
}

function buildScanArgs(params: Record<string, unknown>, mode: string) {
  if (stringParam(params.ruleFile) && stringParam(params.inlineRules)) {
    throw new Error("ast_grep_scan cannot combine ruleFile and inlineRules");
  }
  const args = ["scan", "--color", "never"];
  pushOptional(args, "--config", stringParam(params.config)?.replace(/^@/, ""));
  pushOptional(args, "--rule", stringParam(params.ruleFile)?.replace(/^@/, ""));
  pushOptional(args, "--inline-rules", stringParam(params.inlineRules));
  pushOptional(args, "--filter", stringParam(params.filter));
  if (params.includeMetadata === true) args.push("--include-metadata");
  const json = choiceValue(stringParam(params.json), JSON_STYLES, "json", "none");
  if (mode === "apply") {
    if (json !== "none")
      throw new Error("ast_grep_scan mode=apply cannot combine with json output");
    args.push("--update-all");
  } else if (json !== "none") {
    args.push(`--json=${json}`);
  }
  pushNumber(args, "--max-results", params.maxResults);
  pushSharedArgs(args, params);
  args.push(...normalizePaths(params.paths));
  return args;
}

function pushSharedArgs(args: string[], params: Record<string, unknown>) {
  if (params.follow === true) args.push("--follow");
  for (const glob of stringArrayParam(params.globs)) args.push("--globs", glob);
  for (const value of stringArrayParam(params.noIgnore)) {
    if (!NO_IGNORE_VALUES.has(value)) throw new Error(`Invalid noIgnore '${value}'`);
    args.push("--no-ignore", value);
  }
  pushNumber(args, "--threads", params.threads);
}

function pushChoice(
  args: string[],
  flag: string,
  value: string | undefined,
  allowed: Set<string>,
  name: string
) {
  if (!value) return;
  args.push(flag, choiceValue(value, allowed, name));
}

function choiceValue(
  value: string | undefined,
  allowed: Set<string>,
  name: string,
  fallback?: string
) {
  const selected = value ?? fallback;
  if (!selected) throw new Error(`Missing ${name}`);
  if (!allowed.has(selected))
    throw new Error(`Invalid ${name} '${selected}'. Expected one of: ${[...allowed].join(", ")}`);
  return selected;
}

function pushOptional(args: string[], flag: string, value: string | undefined) {
  if (value) args.push(flag, value);
}

function pushNumber(args: string[], flag: string, value: unknown) {
  const number = numberParam(value);
  if (number !== undefined) args.push(flag, String(number));
}

function stringParam(value: unknown) {
  return typeof value === "string" && value.trim() ? value.trim() : undefined;
}

function numberParam(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) ? Math.trunc(value) : undefined;
}

function stringArrayParam(value: unknown) {
  if (!Array.isArray(value)) return [];
  return value
    .filter((item): item is string => typeof item === "string" && item.trim().length > 0)
    .map((item) => item.trim());
}

function normalizePaths(value: unknown) {
  const paths = stringArrayParam(value).map(stripAtPrefix);
  return paths.length ? paths : ["."];
}

function stripAtPrefix(value: string) {
  return value.startsWith("@") ? value.slice(1) : value;
}

function timeoutMs(timeoutSeconds: unknown) {
  const seconds = numberParam(timeoutSeconds);
  return seconds ? seconds * 1_000 : DEFAULT_TIMEOUT_MS;
}

async function findAstGrepBinary() {
  const candidates = [
    join(PACKAGE_ROOT, "node_modules", ".bin", "ast-grep"),
    join(PACKAGE_ROOT, "node_modules", ".bin", "sg"),
    "/opt/homebrew/bin/ast-grep",
    "/opt/homebrew/bin/sg",
    "/usr/local/bin/ast-grep",
    "/usr/local/bin/sg",
  ];
  for (const candidate of candidates) {
    try {
      await access(candidate, constants.X_OK);
      return candidate;
    } catch {
      // try next candidate
    }
  }
  return "ast-grep";
}

function runCommand(
  command: string,
  args: string[],
  cwd: string,
  signal: AbortSignal | undefined,
  timeout: number,
  allowedExitCodes = [0]
) {
  return new Promise<CommandResult>((resolve, reject) => {
    execFile(
      command,
      args,
      {
        cwd,
        signal,
        timeout,
        maxBuffer: 100 * 1024 * 1024,
        windowsHide: true,
      },
      (error, stdout, stderr) => {
        const err = error as (Error & { code?: string | number; signal?: string }) | null;
        const exitCode = typeof err?.code === "number" ? err.code : 0;
        const result = {
          stdout: String(stdout ?? ""),
          stderr: String(stderr ?? ""),
          exitCode,
        };
        if (err && !allowedExitCodes.includes(exitCode)) {
          reject(new AstGrepCommandError(command, args, result));
          return;
        }
        resolve(result);
      }
    );
  });
}

async function safeGitStatus(cwd: string, signal?: AbortSignal) {
  try {
    await runCommand("git", ["rev-parse", "--is-inside-work-tree"], cwd, signal, 10_000);
    const result = await runCommand("git", ["status", "--short"], cwd, signal, 10_000);
    return result.stdout.trimEnd();
  } catch {
    return "";
  }
}

async function safeGitDiff(cwd: string, paths: string[], signal?: AbortSignal) {
  try {
    await runCommand("git", ["rev-parse", "--is-inside-work-tree"], cwd, signal, 10_000);
    const result = await runCommand(
      "git",
      ["diff", "--no-ext-diff", "--", ...paths],
      cwd,
      signal,
      10_000
    );
    return result.stdout.trimEnd();
  } catch {
    return "";
  }
}

async function formatResult(input: {
  command: string;
  args: string[];
  cwd: string;
  result: CommandResult;
  emptyText: string;
}) {
  const stdout = input.result.stdout.trimEnd();
  const stderr = input.result.stderr.trimEnd();
  const raw =
    stdout || stderr
      ? [stdout, stderr ? `[stderr]\n${stderr}` : ""].filter(Boolean).join("\n\n")
      : input.emptyText;
  const truncated = truncate(raw);
  let text = truncated.content;
  const details: ToolOutputDetails = {
    command: [input.command, ...input.args],
    cwd: input.cwd,
    exitCode: input.result.exitCode,
    stdoutBytes: Buffer.byteLength(input.result.stdout),
    stderrBytes: Buffer.byteLength(input.result.stderr),
  };
  if (truncated.truncated) {
    const dir = await mkdtemp(join(tmpdir(), "pi-ast-grep-"));
    const file = join(dir, "output.txt");
    await writeFile(file, raw, "utf8");
    details.fullOutputPath = file;
    details.truncation = {
      truncated: true,
      totalLines: truncated.totalLines,
      outputLines: truncated.outputLines,
      totalBytes: truncated.totalBytes,
      outputBytes: truncated.outputBytes,
    };
    text += `\n\n[Output truncated: showing ${truncated.outputLines} of ${truncated.totalLines} lines (${formatBytes(truncated.outputBytes)} of ${formatBytes(truncated.totalBytes)}). Full output saved to: ${file}]`;
  }
  return {
    content: [{ type: "text" as const, text }],
    details,
  };
}

function truncate(value: string) {
  const lines = value.split("\n");
  const totalLines = lines.length;
  const totalBytes = Buffer.byteLength(value);
  let content = lines.slice(0, MAX_LINES).join("\n");
  if (Buffer.byteLength(content) > MAX_BYTES) {
    content = Buffer.from(content).subarray(0, MAX_BYTES).toString("utf8");
  }
  const outputLines = content ? content.split("\n").length : 0;
  const outputBytes = Buffer.byteLength(content);
  return {
    content,
    truncated: totalLines > outputLines || totalBytes > outputBytes,
    totalLines,
    outputLines,
    totalBytes,
    outputBytes,
  };
}

function formatBytes(bytes: number) {
  if (bytes < 1024) return `${bytes} B`;
  const kib = bytes / 1024;
  if (kib < 1024) return `${kib.toFixed(1)} KiB`;
  return `${(kib / 1024).toFixed(1)} MiB`;
}
