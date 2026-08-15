import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { basename, dirname } from "node:path";

import { fetchPrInfo, openReviewBox } from "./pr-review-workspace.js";
import type { ExecFn, PrInfo, ReviewBoxResult } from "./pr-review-workspace.js";
// Re-export shared helpers, types, primitives, and the decision flow from the
// extracted module for backward compatibility and bridge consumption.
export {
  slugify,
  findStringKey,
  buildReviewPrompt,
  buildApprovalCommand,
  parsePrInfo,
  fetchPrInfo,
  prepareReviewWorktree,
  refreshReviewWorktree,
  createHerdrReviewWorkspace,
  openReviewBox,
} from "./pr-review-workspace.js";
export type {
  PrInfo,
  ExecFn,
  ReviewBoxManifest,
  ReviewBoxResult,
  OpenReviewBoxOpts,
} from "./pr-review-workspace.js";

const HERDR_TIMEOUT_MS = 10_000;

const stringify = (value: unknown): string =>
  typeof value === "string" ? value : JSON.stringify(value, null, 2);

const textResult = (text: string, details: Record<string, unknown> = {}) => ({
  content: [{ type: "text" as const, text }],
  details,
});

const runHerdr = async (
  pi: ExtensionAPI,
  args: string[],
  options: { cwd?: string; timeout?: number } = {}
) => {
  const result = await pi.exec("herdr", args, {
    cwd: options.cwd ?? process.cwd(),
    timeout: options.timeout ?? HERDR_TIMEOUT_MS,
  });

  const stdout = result.stdout?.trim() ?? "";
  const stderr = result.stderr?.trim() ?? "";

  if (result.code !== 0) {
    throw new Error(
      [`herdr ${args.join(" ")} failed with exit code ${result.code}`, stdout, stderr]
        .filter(Boolean)
        .join("\n\n")
    );
  }

  return { stdout, stderr, code: result.code };
};

const runCommand = async (
  pi: ExtensionAPI,
  command: string,
  args: string[],
  options: { cwd?: string; timeout?: number } = {}
) => {
  const result = await pi.exec(command, args, {
    cwd: options.cwd ?? process.cwd(),
    timeout: options.timeout ?? HERDR_TIMEOUT_MS,
  });

  const stdout = result.stdout?.trim() ?? "";
  const stderr = result.stderr?.trim() ?? "";

  if (result.code !== 0) {
    throw new Error(
      [`${command} ${args.join(" ")} failed with exit code ${result.code}`, stdout, stderr]
        .filter(Boolean)
        .join("\n\n")
    );
  }

  return { stdout, stderr, code: result.code };
};

const parseJson = (text: string): unknown => {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
};

type ReviewWorkspaceParams = {
  pr: string;
  repo?: string;
  base?: string;
  worktreeName?: string;
  prompt?: string;
  agent?: "omp" | "pi";
};

type ReviewBoxOptions = {
  stateRoot?: string;
};

/**
 * Thin adapter: derives repoRoot and sharedRoot from the Pi tool's cwd,
 * fetches PrInfo via the shared helper (one gh call, no state — as today),
 * then delegates the full decision flow to openReviewBox in the shared module.
 */
export const openPrReviewWorkspace = async (
  pi: ExtensionAPI,
  params: ReviewWorkspaceParams,
  startCwd: string,
  options: ReviewBoxOptions = {}
): Promise<ReviewBoxResult> => {
  const exec: ExecFn = (cmd, args, opts) => pi.exec(cmd, args, opts);

  const repoRoot = (
    await runCommand(pi, "git", ["rev-parse", "--show-toplevel"], {
      cwd: params.repo ?? startCwd,
    })
  ).stdout;

  const pr = await fetchPrInfo(exec, params.pr, { cwd: repoRoot });

  const gitCommonDir = (
    await runCommand(pi, "git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], {
      cwd: repoRoot,
    })
  ).stdout;
  const sharedRoot = basename(gitCommonDir) === ".git" ? dirname(gitCommonDir) : repoRoot;

  return openReviewBox(exec, {
    pr,
    repoRoot,
    sharedRoot,
    prIdentifier: params.pr,
    base: params.base,
    worktreeName: params.worktreeName,
    prompt: params.prompt,
    agent: params.agent,
    stateRoot: options.stateRoot,
  });
};

const reviewBoxSummary = (result: ReviewBoxResult): string =>
  [
    `${result.action[0]?.toUpperCase()}${result.action.slice(1)} Herdr Review Box for PR #${result.pr.number}.`,
    `Worktree: ${result.worktreePath}`,
    `Diff: ${result.diffTarget}`,
    `Tabs: Hunk, Critique, ${result.agent === "pi" ? "Pi Review" : "OMP Review"}, Approve`,
  ].join("\n");

export default function herdrExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "herdr_status",
    label: "Herdr Status",
    description: "Check the local herdr client/server status and socket compatibility.",
    parameters: Type.Object({}),
    async execute(_toolCallId, _params, _signal, _onUpdate, _ctx) {
      const result = await runHerdr(pi, ["status"]);
      return textResult(result.stdout || "herdr status returned no output", result);
    },
  });

  pi.registerTool({
    name: "herdr_list",
    label: "Herdr List",
    description: "List herdr workspaces, tabs, or panes using the running herdr server.",
    parameters: Type.Object({
      resource: Type.Union(
        [Type.Literal("workspaces"), Type.Literal("tabs"), Type.Literal("panes")],
        { description: "Which herdr resource to list." }
      ),
      workspaceId: Type.Optional(
        Type.String({ description: "Optional workspace id filter for tabs or panes." })
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const args =
        params.resource === "workspaces"
          ? ["workspace", "list"]
          : params.resource === "tabs"
            ? ["tab", "list"]
            : ["pane", "list"];

      if (params.workspaceId && params.resource !== "workspaces") {
        args.push("--workspace", params.workspaceId);
      }

      const result = await runHerdr(pi, args);
      const parsed = parseJson(result.stdout);
      return textResult(stringify(parsed), { ...result, parsed });
    },
  });

  pi.registerTool({
    name: "herdr_read_pane",
    label: "Herdr Read Pane",
    description: "Read visible or recent output from a herdr pane.",
    parameters: Type.Object({
      paneId: Type.String({ description: "Stable herdr pane id, e.g. w...-1 or positional 1-1." }),
      source: Type.Optional(
        Type.Union(
          [Type.Literal("visible"), Type.Literal("recent"), Type.Literal("recent-unwrapped")],
          { description: "Output source. Defaults to recent." }
        )
      ),
      lines: Type.Optional(
        Type.Number({ description: "Number of lines to read. Defaults to 80; herdr caps at 1000." })
      ),
      ansi: Type.Optional(Type.Boolean({ description: "Preserve ANSI formatting." })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const args = ["pane", "read", params.paneId, "--source", params.source ?? "recent"];
      if (params.lines) args.push("--lines", String(params.lines));
      if (params.ansi) args.push("--ansi");
      const result = await runHerdr(pi, args);
      return textResult(result.stdout || "(pane output empty)", result);
    },
  });

  pi.registerTool({
    name: "herdr_run_in_pane",
    label: "Herdr Run In Pane",
    description: "Send a command to a herdr pane and press Enter via `herdr pane run`.",
    parameters: Type.Object({
      paneId: Type.String({ description: "Target herdr pane id." }),
      command: Type.String({ description: "Command text to send to the pane." }),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const result = await runHerdr(pi, ["pane", "run", params.paneId, params.command]);
      return textResult("Command sent to herdr pane.", result);
    },
  });

  pi.registerTool({
    name: "herdr_wait",
    label: "Herdr Wait",
    description: "Wait for pane output to match text/regex or for an agent status transition.",
    parameters: Type.Object({
      kind: Type.Union([Type.Literal("output"), Type.Literal("agent-status")]),
      paneId: Type.String({ description: "Target herdr pane id." }),
      match: Type.Optional(
        Type.String({ description: "Text or regex to match when kind is output." })
      ),
      regex: Type.Optional(
        Type.Boolean({ description: "Treat match as a regex for output waits." })
      ),
      status: Type.Optional(
        Type.Union(
          [
            Type.Literal("idle"),
            Type.Literal("working"),
            Type.Literal("blocked"),
            Type.Literal("done"),
            Type.Literal("unknown"),
          ],
          { description: "Agent status when kind is agent-status." }
        )
      ),
      timeoutMs: Type.Optional(
        Type.Number({ description: "Timeout in milliseconds. Defaults to 60000." })
      ),
      lines: Type.Optional(Type.Number({ description: "Lines to scan for output waits." })),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, _ctx) {
      const timeout = String(params.timeoutMs ?? 60_000);
      const args = ["wait", params.kind, params.paneId];

      if (params.kind === "output") {
        if (!params.match) throw new Error("match is required for output waits");
        args.push("--match", params.match, "--timeout", timeout);
        if (params.regex) args.push("--regex");
        if (params.lines) args.push("--lines", String(params.lines));
      } else {
        if (!params.status) throw new Error("status is required for agent-status waits");
        args.push("--status", params.status, "--timeout", timeout);
      }

      const result = await runHerdr(pi, args, { timeout: Number(timeout) + 2_000 });
      const parsed = parseJson(result.stdout);
      return textResult(stringify(parsed), { ...result, parsed });
    },
  });

  pi.registerTool({
    name: "herdr_pr_review_workspace",
    label: "Herdr PR Review Workspace",
    description:
      "Create a PR review git worktree, open a Herdr workspace with Hunk, start an OMP review tab, and add an approval tab.",
    parameters: Type.Object({
      pr: Type.String({
        description: "Pull request number, URL, or branch accepted by `gh pr view`.",
      }),
      repo: Type.Optional(
        Type.String({ description: "Repository path. Defaults to the current OMP/Pi cwd." })
      ),
      base: Type.Optional(
        Type.String({
          description: "Optional base ref for the Hunk diff. Defaults to origin/<PR base>.",
        })
      ),
      worktreeName: Type.Optional(
        Type.String({ description: "Optional worktree slug. Defaults to pr-<number>-<title>." })
      ),
      prompt: Type.Optional(
        Type.String({
          description: "Optional extra instruction appended to the OMP review prompt.",
        })
      ),
      agent: Type.Optional(
        Type.Union([Type.Literal("omp"), Type.Literal("pi")], {
          description: "Review agent tab. Defaults to OMP; Pi is an explicit override.",
        })
      ),
    }),
    async execute(_toolCallId, params, _signal, _onUpdate, ctx) {
      const startCwd = params.repo ?? ctx?.cwd ?? process.cwd();
      const result = await openPrReviewWorkspace(pi, params, startCwd);
      return textResult(reviewBoxSummary(result), result);
    },
  });

  pi.registerCommand("review-box", {
    description: "Create or resume one Herdr Review Box for a GitHub pull request",
    handler: async (args, ctx) => {
      const argv = args.trim().split(/\s+/).filter(Boolean);
      const pr = argv[0];
      if (!pr) {
        ctx.ui.notify("Usage: /review-box <pr-number|url|branch> [--agent omp|pi]", "info");
        return;
      }
      const agentIndex = argv.indexOf("--agent");
      const agentValue = agentIndex >= 0 ? argv[agentIndex + 1] : undefined;
      if (agentValue !== undefined && agentValue !== "omp" && agentValue !== "pi") {
        ctx.ui.notify("--agent must be omp or pi", "error");
        return;
      }
      const agent = agentValue === "pi" ? "pi" : agentValue === "omp" ? "omp" : undefined;
      try {
        const result = await openPrReviewWorkspace(pi, { pr, agent }, ctx.cwd);
        ctx.ui.notify(reviewBoxSummary(result), "info");
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
      }
    },
  });

  pi.registerCommand("herdr", {
    description: "Run a herdr CLI command from inside Pi, e.g. /herdr pane list",
    handler: async (args, ctx) => {
      const argv = args.trim().split(/\s+/).filter(Boolean);
      if (argv.length === 0) {
        ctx.ui.notify("Usage: /herdr <status|workspace|tab|pane|wait ...>", "info");
        return;
      }
      try {
        const result = await runHerdr(pi, argv, { cwd: ctx.cwd, timeout: 30_000 });
        ctx.ui.notify(result.stdout || "herdr command completed", "info");
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
      }
    },
  });
}
