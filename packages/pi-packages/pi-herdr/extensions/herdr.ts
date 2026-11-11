import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { basename, dirname } from "node:path";

import { fetchPrInfo, openReviewBox, reviewTabLabel } from "./pr-review-workspace.js";
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

const textResult = (text: string, details: Record<string, unknown> = {}) => ({
  content: [{ type: "text" as const, text }],
  details,
});

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

type ReviewWorkspaceParams = {
  pr: string;
  repo?: string;
  base?: string;
  worktreeName?: string;
  prompt?: string;
  agent?: string;
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
    `Tabs: Hunk, Critique, ${reviewTabLabel(result.agent)}, Approve`,
  ].join("\n");

export default function herdrExtension(pi: ExtensionAPI) {
  pi.registerTool({
    name: "herdr_pr_review_workspace",
    label: "Herdr PR Review Workspace",
    description:
      "Create a PR review git worktree, open a Herdr workspace with Hunk, start a review agent tab, and add an approval tab.",
    parameters: Type.Object({
      pr: Type.String({
        description: "Pull request number, URL, or branch accepted by `gh pr view`.",
      }),
      repo: Type.Optional(
        Type.String({ description: "Repository path. Defaults to the current Pi cwd." })
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
          description: "Optional extra instruction appended to the review prompt.",
        })
      ),
      agent: Type.Optional(
        Type.String({
          description:
            "Review agent command, such as pi, claude or codex. Defaults to $DEFAULT_CODING_AGENT, then pi.",
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
        ctx.ui.notify("Usage: /review-box <pr-number|url|branch> [--agent <command>]", "info");
        return;
      }
      const agentIndex = argv.indexOf("--agent");
      const agent = agentIndex >= 0 ? argv[agentIndex + 1] : undefined;
      if (agentIndex >= 0 && !agent) {
        ctx.ui.notify("--agent needs a command name", "error");
        return;
      }
      try {
        const result = await openPrReviewWorkspace(pi, { pr, agent }, ctx.cwd);
        ctx.ui.notify(reviewBoxSummary(result), "info");
      } catch (error) {
        ctx.ui.notify(error instanceof Error ? error.message : String(error), "error");
      }
    },
  });
}
