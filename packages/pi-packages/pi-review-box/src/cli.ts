#!/usr/bin/env bun
/**
 * review-box — thin CLI adapter bridging ghui PR JSON to pi-herdr's
 * shared openReviewBox decision flow.
 *
 * Pipeline: parse stdin → resolve repoRoot from config → revalidate via
 * ONE read-only `gh pr view` (incl. state) → delegate to openReviewBox →
 * map result to stdout JSON.
 *
 * Exit codes (R1): 0 success, 2 input/usage, 3 closed/merged,
 * 4 gh failure, 5 repo-root config class, 6 herdr/git runtime failure.
 */

import { basename, dirname } from "node:path";
import { exec, ExecError } from "./exec.ts";
import { readAndParseStdin } from "./stdin.ts";
import { resolveRepoRoot } from "./config.ts";
import { pruneReviewBoxes } from "./prune.ts";
import {
  openReviewBox,
  parsePrInfo,
  type PrInfo,
  type ExecFn,
} from "pi-herdr/extensions/pr-review-workspace.ts";

const USAGE = `usage: review-box [--help|-h] [prune]

Promote or resume a Herdr Review Box for a GitHub pull request.

Reads one JSON object from stdin with fields:
  repository   "owner/name" (required, case-insensitive)
  number       PR number (required, positive integer)
  headRefOid   HEAD commit SHA hint (required, revalidated via gh)
  headRefName  branch name hint (required, revalidated via gh)
  title        PR title hint (required, revalidated via gh)
  url          PR URL (required, revalidated via gh)

Revalidates via one read-only \`gh pr view\` call, then delegates to
pi-herdr's shared openReviewBox decision flow.

Subcommands:
  prune    Remove manifest files whose workspace and worktree are both gone.

Exit codes:
  0  success (created/resumed/restored/refreshed)
  2  input/usage error
  3  PR is closed or merged
  4  gh failure (non-zero exit, timeout, missing fields)
  5  repo-root config class failure (unmapped repo, malformed config)
  6  herdr/git runtime failure or timeout
`;

class BridgeError extends Error {
  constructor(
    public exitCode: number,
    message: string
  ) {
    super(message);
    this.name = "BridgeError";
  }
}

function fail(error: BridgeError): never {
  process.stdout.write(JSON.stringify({ error: error.message }) + "\n");
  process.stderr.write(error.message + "\n");
  process.exit(error.exitCode);
}

/**
 * Classify an error from the shared openReviewBox flow or exec layer
 * into the appropriate exit code per R1.
 */
function classifyError(err: unknown): BridgeError {
  if (err instanceof BridgeError) return err;
  if (err instanceof ExecError) {
    // gh failures → exit 4; herdr/git failures → exit 6
    const exitCode = err.cmd === "gh" ? 4 : 6;
    return new BridgeError(exitCode, err.enoent ? `${err.cmd} not found on PATH` : err.message);
  }
  return new BridgeError(6, err instanceof Error ? err.message : String(err));
}

// ─── Promote/resume flow ─────────────────────────────────────────────

async function runPromote(): Promise<void> {
  // 1. TTY stdin → usage error
  if (process.stdin.isTTY) {
    process.stdout.write(
      JSON.stringify({ error: "stdin must be piped (JSON), not a terminal" }) + "\n"
    );
    process.stderr.write(USAGE);
    process.exit(2);
  }

  // 2. Read and parse stdin
  let input;
  try {
    input = await readAndParseStdin();
  } catch (err) {
    throw new BridgeError(2, err instanceof Error ? err.message : String(err));
  }

  // 3. Resolve repoRoot from config (REVIEW_BOX_REPO_ROOT ignored per R7)
  let repoRoot: string;
  try {
    repoRoot = await resolveRepoRoot(input.repository);
  } catch (err) {
    throw new BridgeError(5, err instanceof Error ? err.message : String(err));
  }

  // 4. gh revalidation — exactly ONE read-only call
  let pr: PrInfo;
  try {
    const result = await exec(
      "gh",
      [
        "pr",
        "view",
        String(input.number),
        "--repo",
        input.repository,
        "--json",
        "number,title,baseRefName,headRefName,headRefOid,url,state",
      ],
      { timeout: 30_000 }
    );

    if (result.code !== 0) {
      throw new BridgeError(
        4,
        `gh pr view failed (exit ${result.code}): ${result.stderr.trim() || "unknown error"}`
      );
    }

    try {
      pr = parsePrInfo(result.stdout);
    } catch (err) {
      throw new BridgeError(
        4,
        `gh returned invalid data: ${err instanceof Error ? err.message : String(err)}`
      );
    }
  } catch (err) {
    if (err instanceof BridgeError) throw err;
    if (err instanceof ExecError) {
      throw new BridgeError(4, err.enoent ? "gh not found on PATH" : err.message);
    }
    throw new BridgeError(4, err instanceof Error ? err.message : String(err));
  }

  // 5. Non-OPEN PR → exit 3, open nothing
  if (pr.state !== "OPEN") {
    process.stdout.write(JSON.stringify({ status: "closed", state: pr.state ?? "UNKNOWN" }) + "\n");
    process.exit(3);
  }

  // 6. Derive sharedRoot from repoRoot
  let sharedRoot: string;
  try {
    const result = await exec("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], {
      cwd: repoRoot,
      timeout: 60_000,
    });
    if (result.code !== 0) {
      throw new BridgeError(
        6,
        `git rev-parse failed (exit ${result.code}): ${result.stderr.trim()}`
      );
    }
    const gitCommonDir = result.stdout.trim();
    sharedRoot = basename(gitCommonDir) === ".git" ? dirname(gitCommonDir) : repoRoot;
  } catch (err) {
    if (err instanceof BridgeError) throw err;
    if (err instanceof ExecError) {
      throw new BridgeError(6, err.enoent ? "git not found on PATH" : err.message);
    }
    throw new BridgeError(6, err instanceof Error ? err.message : String(err));
  }

  // 7. Health check: if herdr is unavailable, exit 6 before delegating
  //    (prevents workspace-create attempts when herdr is down — VAL-BRIDGE-030c)
  try {
    const health = await exec("herdr", ["workspace", "list"], { timeout: 10_000 });
    if (health.code !== 0) {
      throw new BridgeError(6, `herdr is unavailable (exit ${health.code})`);
    }
  } catch (err) {
    if (err instanceof BridgeError) throw err;
    if (err instanceof ExecError) {
      throw new BridgeError(6, err.enoent ? "herdr not found on PATH" : err.message);
    }
    throw new BridgeError(6, err instanceof Error ? err.message : String(err));
  }

  // 8. Delegate to the shared openReviewBox decision flow
  const bridgeExec: ExecFn = exec;
  let result;
  try {
    result = await openReviewBox(bridgeExec, {
      pr,
      repoRoot,
      sharedRoot,
      prIdentifier: String(pr.number),
    });
  } catch (err) {
    throw classifyError(err);
  }

  // 8. Map result to stdout JSON
  process.stdout.write(
    JSON.stringify({
      status: result.action,
      workspaceId: result.workspaceId,
      worktreePath: result.worktreePath,
      headRefOid: result.pr.headRefOid,
    }) + "\n"
  );
  process.stderr.write(
    `${result.action[0]?.toUpperCase()}${result.action.slice(1)} review box for PR #${result.pr.number}.\n`
  );
  process.exit(0);
}

// ─── Prune flow ──────────────────────────────────────────────────────

async function runPrune(): Promise<void> {
  try {
    const result = await pruneReviewBoxes();
    process.stdout.write(JSON.stringify({ removed: result.removed }) + "\n");
    process.exit(0);
  } catch (err) {
    if (err instanceof ExecError) {
      throw new BridgeError(6, err.enoent ? `${err.cmd} not found on PATH` : err.message);
    }
    throw new BridgeError(6, err instanceof Error ? err.message : String(err));
  }
}

// ─── Main entry point ────────────────────────────────────────────────

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const subcommand = args[0];

  if (subcommand === "--help" || subcommand === "-h") {
    process.stdout.write(USAGE);
    process.exit(0);
  }

  if (subcommand === "prune") {
    try {
      await runPrune();
    } catch (err) {
      if (err instanceof BridgeError) fail(err);
      fail(new BridgeError(6, err instanceof Error ? err.message : String(err)));
    }
    return;
  }

  if (subcommand !== undefined) {
    // Unknown subcommand → usage on stderr, exit 2
    process.stderr.write(USAGE);
    process.exit(2);
  }

  // Default: promote/resume
  try {
    await runPromote();
  } catch (err) {
    if (err instanceof BridgeError) fail(err);
    fail(classifyError(err));
  }
}

main();
