/**
 * Standalone, exec-parameterized PR-review workspace orchestration.
 *
 * Extracted from pi-herdr's herdr_pr_review_workspace tool so that both the
 * Pi extension and the future review-box CLI share a single implementation.
 *
 * This module does NOT import the Pi extension SDK — every spawned
 * process goes through an injected ExecFn, making it consumable from a plain
 * bun CLI.
 */

import { mkdir, stat } from "node:fs/promises";
import { basename, dirname, join } from "node:path";

// ─── Constants ───────────────────────────────────────────────────────

const HERDR_TIMEOUT_MS = 10_000;

// ─── ExecFn type ─────────────────────────────────────────────────────

export type ExecFn = (
  cmd: string,
  args: string[],
  opts?: { cwd?: string; timeout?: number }
) => Promise<{ stdout: string; stderr: string; code: number }>;

// ─── Types ───────────────────────────────────────────────────────────

export type PrInfo = {
  number: number;
  title: string;
  baseRefName: string;
  headRefName: string;
  headRefOid: string;
  url: string;
};

// ─── Exported shared helpers ─────────────────────────────────────────

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

export const slugify = (value: string): string =>
  value
    .toLowerCase()
    .replace(/[^a-z0-9_-]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .replace(/-+/g, "-");

export const findStringKey = (value: unknown, keys: Set<string>): string | undefined => {
  if (Array.isArray(value)) {
    for (const item of value) {
      const found = findStringKey(item, keys);
      if (found) return found;
    }
    return undefined;
  }
  if (!isRecord(value)) return undefined;
  for (const [key, item] of Object.entries(value)) {
    if (keys.has(key) && typeof item === "string" && item) return item;
    const found = findStringKey(item, keys);
    if (found) return found;
  }
  return undefined;
};

export const parsePrInfo = (stdout: string): PrInfo => {
  const parsed: unknown = JSON.parse(stdout);
  if (!isRecord(parsed)) throw new Error("gh pr view returned non-object JSON");
  const { number, title, baseRefName, headRefName, headRefOid, url } = parsed;
  if (
    typeof number !== "number" ||
    typeof title !== "string" ||
    typeof baseRefName !== "string" ||
    typeof headRefName !== "string" ||
    typeof headRefOid !== "string" ||
    typeof url !== "string"
  ) {
    throw new Error("gh pr view returned incomplete PR metadata");
  }
  return { number, title, baseRefName, headRefName, headRefOid, url };
};

export const buildReviewPrompt = (input: {
  pr: PrInfo;
  repo: string;
  diffTarget: string;
  hunkTab: string;
}): string =>
  [
    "/review",
    "",
    `Review PR #${input.pr.number}: ${input.pr.title}`,
    `URL: ${input.pr.url}`,
    `Repo: ${input.repo}`,
    `Diff: ${input.diffTarget}`,
    "",
    `A Herdr tab named ${input.hunkTab} is open with the Hunk diff.`,
    "Use Hunk as the review surface.",
    "Start with hunk session review --repo . --json, then include patches only as needed.",
    "Leave inline Hunk comments for actionable findings using hunk_comments action=apply or hunk session comment apply.",
    "Prioritize bugs, regressions, missing tests, and merge risks.",
    "Do not edit code unless asked.",
    "End with an approve/request-changes recommendation.",
  ].join("\n");

export const buildApprovalCommand = (prUrl: string): string =>
  [
    "printf '%s\\n' 'Review actions:'",
    `printf '%s\\n' '  gh pr review ${prUrl} --approve'`,
    `printf '%s\\n' '  gh pr review ${prUrl} --request-changes -b \"<reason>\"'`,
    `printf '%s\\n' '  gh pr review ${prUrl} --comment -b \"<summary>\"'`,
    `printf '%s\\n' '  gh pr view ${prUrl} --web'`,
    "exec ${SHELL:-/bin/zsh} -l",
  ].join("; ");

// ─── Internal helpers ────────────────────────────────────────────────

const truncate = (value: string, maxLength: number): string =>
  value.length <= maxLength ? value : value.slice(0, maxLength).replace(/-+$/g, "");

const shellQuote = (value: string): string => `'${value.replace(/'/g, "'\\''")}'`;

const parseJson = (text: string): unknown => {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
};

const pathExists = async (path: string): Promise<boolean> =>
  stat(path)
    .then(() => true)
    .catch(() => false);

const runHerdr = async (
  exec: ExecFn,
  args: string[],
  options: { cwd?: string; timeout?: number } = {}
) => {
  const result = await exec("herdr", args, {
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
  exec: ExecFn,
  command: string,
  args: string[],
  options: { cwd?: string; timeout?: number } = {}
) => {
  const result = await exec(command, args, {
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

const hunkDiffCommand = (diffTarget: string): string =>
  [
    "if command -v hunk >/dev/null 2>&1; then",
    `exec hunk diff ${shellQuote(diffTarget)} --no-transparent-bg;`,
    "fi;",
    `exec bunx hunkdiff diff ${shellQuote(diffTarget)} --no-transparent-bg`,
  ].join(" ");

const critiqueDiffCommand = (diffBase: string): string =>
  `exec critique ${shellQuote(diffBase)} HEAD`;

const createTabAndRun = async (
  exec: ExecFn,
  workspaceId: string,
  cwd: string,
  label: string,
  command: string
) => {
  const tab = await runHerdr(exec, [
    "tab",
    "create",
    "--workspace",
    workspaceId,
    "--cwd",
    cwd,
    "--label",
    label,
    "--no-focus",
  ]);
  const paneId = findStringKey(parseJson(tab.stdout), new Set(["pane_id"]));
  if (!paneId) throw new Error(`could not find pane_id for ${label} tab`);
  await runHerdr(exec, ["pane", "rename", paneId, label]);
  await runHerdr(exec, ["pane", "run", paneId, command]);
  return paneId;
};

// ─── Exported primitives ─────────────────────────────────────────────

export async function prepareReviewWorktree(
  exec: ExecFn,
  opts: {
    repoRoot: string;
    sharedRoot: string;
    prIdentifier: string;
    prNumber: number;
    headRefName: string;
    baseRefName: string;
    worktreeName?: string;
    base?: string;
  }
): Promise<{ worktreePath: string; diffTarget: string }> {
  const { repoRoot, sharedRoot, prIdentifier, prNumber, headRefName, baseRefName } = opts;

  const requestedSlug = truncate(
    slugify(opts.worktreeName ?? `pr-${prNumber}-${headRefName}`) || `pr-${prNumber}`,
    60
  );
  const worktreePath = join(sharedRoot, ".pi", "worktrees", requestedSlug);
  const diffBase = opts.base ?? `origin/${baseRefName}`;
  const diffTarget = `${diffBase}...HEAD`;

  if (!opts.base) {
    await runCommand(exec, "git", ["fetch", "origin", baseRefName], {
      cwd: repoRoot,
      timeout: 60_000,
    });
  }

  if (!(await pathExists(worktreePath))) {
    await mkdir(dirname(worktreePath), { recursive: true });
    await runCommand(exec, "git", ["worktree", "add", "--detach", worktreePath, diffBase], {
      cwd: repoRoot,
      timeout: 60_000,
    });
  }

  await runCommand(exec, "gh", ["pr", "checkout", prIdentifier, "--detach", "--force"], {
    cwd: worktreePath,
    timeout: 60_000,
  });

  return { worktreePath, diffTarget };
}

export async function refreshReviewWorktree(
  exec: ExecFn,
  opts: {
    repoRoot: string;
    worktreePath: string;
    prIdentifier: string;
    baseRefName: string;
    customBase: boolean;
  }
): Promise<{ headRefOid: string }> {
  const { repoRoot, worktreePath, prIdentifier, baseRefName, customBase } = opts;

  if (!customBase) {
    await runCommand(exec, "git", ["fetch", "origin", baseRefName], {
      cwd: repoRoot,
      timeout: 60_000,
    });
  }
  await runCommand(exec, "gh", ["pr", "checkout", prIdentifier, "--detach", "--force"], {
    cwd: worktreePath,
    timeout: 60_000,
  });
  const head = (await runCommand(exec, "git", ["rev-parse", "HEAD"], { cwd: worktreePath })).stdout;

  return { headRefOid: head };
}

export async function createHerdrReviewWorkspace(
  exec: ExecFn,
  opts: {
    worktreePath: string;
    prNumber: number;
    title: string;
    prUrl: string;
    diffTarget: string;
    diffBase: string;
    extraPrompt?: string;
    agent?: "omp" | "pi";
  }
): Promise<{ workspaceId: string }> {
  const { worktreePath, prNumber, title, prUrl, diffTarget, diffBase } = opts;
  const agent = opts.agent ?? "omp";

  const workspaceLabel = truncate(`PR #${prNumber} ${title}`, 56);
  const workspace = await runHerdr(exec, [
    "workspace",
    "create",
    "--cwd",
    worktreePath,
    "--label",
    workspaceLabel,
    "--env",
    "HERDR_REVIEW_BOX=1",
    "--focus",
  ]);
  const workspaceId = findStringKey(parseJson(workspace.stdout), new Set(["workspace_id", "id"]));
  if (!workspaceId) throw new Error("could not find workspace id in Herdr response");

  const reviewPrompt = `${buildReviewPrompt({
    pr: { number: prNumber, title, baseRefName: "", headRefName: "", headRefOid: "", url: prUrl },
    repo: worktreePath,
    diffTarget,
    hunkTab: "Hunk",
  })}${opts.extraPrompt ? `\n\nExtra instruction:\n${opts.extraPrompt}` : ""}`;
  const reviewCommand =
    agent === "pi"
      ? `pi ${shellQuote(reviewPrompt)}`
      : `omp --cwd ${shellQuote(worktreePath)} ${shellQuote(reviewPrompt)}`;

  await createTabAndRun(exec, workspaceId, worktreePath, "Hunk", hunkDiffCommand(diffTarget));
  await createTabAndRun(exec, workspaceId, worktreePath, "Critique", critiqueDiffCommand(diffBase));
  await createTabAndRun(
    exec,
    workspaceId,
    worktreePath,
    agent === "pi" ? "Pi Review" : "OMP Review",
    reviewCommand
  );
  await createTabAndRun(exec, workspaceId, worktreePath, "Approve", buildApprovalCommand(prUrl));
  await runHerdr(exec, ["workspace", "focus", workspaceId]);

  return { workspaceId };
}
