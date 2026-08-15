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

import { mkdir, readFile, rename, rm, stat, unlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

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
  /** Present when fetched with `state` in the --json field list (bridge use). */
  state?: string;
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

  // Envelope-aware: the real herdr CLI wraps responses as
  //   {"id":"cli:workspace:create","result":{"workspace_id":"w41",...}}
  // The top-level "id" is the command name, not a data field. When the
  // envelope shape is present (id is a string AND result is a record),
  // search result first so we prefer data fields over the envelope id.
  // This prevents extracting "cli:workspace:create" as the workspace id.
  if (typeof value.id === "string" && isRecord(value.result)) {
    const found = findStringKey(value.result, keys);
    if (found) return found;
  }

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
  const { number, title, baseRefName, headRefName, headRefOid, url, state } = parsed;
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
  return {
    number,
    title,
    baseRefName,
    headRefName,
    headRefOid,
    url,
    ...(typeof state === "string" ? { state } : {}),
  };
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

  // R4: tolerate an existing worktree path left by a prior exit-6 partial run.
  // If the path exists but is not a valid worktree, gh pr checkout will fail —
  // catch that, prune the stale entry, recreate the worktree, and retry.
  try {
    await runCommand(exec, "gh", ["pr", "checkout", prIdentifier, "--detach", "--force"], {
      cwd: worktreePath,
      timeout: 60_000,
    });
  } catch {
    if (!(await pathExists(worktreePath))) {
      await mkdir(dirname(worktreePath), { recursive: true });
    } else {
      await rm(worktreePath, { recursive: true, force: true });
    }
    await runCommand(exec, "git", ["worktree", "prune"], { cwd: repoRoot, timeout: 60_000 });
    await runCommand(exec, "git", ["worktree", "add", "--detach", worktreePath, diffBase], {
      cwd: repoRoot,
      timeout: 60_000,
    });
    await runCommand(exec, "gh", ["pr", "checkout", prIdentifier, "--detach", "--force"], {
      cwd: worktreePath,
      timeout: 60_000,
    });
  }

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
  const workspaceResponse = parseJson(workspace.stdout);
  const workspaceId = findStringKey(workspaceResponse, new Set(["workspace_id", "id"]));
  if (!workspaceId) throw new Error("could not find workspace id in Herdr response");
  const initialTabId = findStringKey(workspaceResponse, new Set(["tab_id"]));

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
  if (initialTabId) await runHerdr(exec, ["tab", "close", initialTabId]);
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

// ─── Manifest types ──────────────────────────────────────────────────

export type ReviewBoxManifest = {
  schemaVersion: 1;
  repoRoot: string;
  prNumber: number;
  prUrl: string;
  headRefOid: string;
  worktreePath: string;
  workspaceId: string;
  diffTarget: string;
  agent: "omp" | "pi";
  updatedAt: string;
};

export type ReviewBoxResult = {
  action: "created" | "restored" | "resumed" | "refreshed";
  pr: PrInfo;
  worktreePath: string;
  workspaceId: string;
  diffTarget: string;
  agent: "omp" | "pi";
};

export type OpenReviewBoxOpts = {
  /** Pre-fetched PR info (caller makes exactly ONE gh call). */
  pr: PrInfo;
  /** Repository root (derived by the caller — Pi uses git rev-parse, bridge uses config). */
  repoRoot: string;
  /** Shared root for worktree placement (derived from --git-common-dir). */
  sharedRoot: string;
  /** PR identifier for `gh pr checkout` (number, URL, or branch). */
  prIdentifier: string;
  /** Custom base ref for the diff. Defaults to origin/<baseRefName>. */
  base?: string;
  /** Custom worktree slug. Defaults to pr-<number>-<headRefName>. */
  worktreeName?: string;
  /** Extra instruction appended to the review prompt. */
  prompt?: string;
  /** Review agent tab. Defaults to sticky manifest value or "omp". */
  agent?: "omp" | "pi";
  /** Override the state directory (testing). */
  stateRoot?: string;
};

// ─── Manifest helpers (moved from herdr.ts) ───────────────────────────

export const defaultStateRoot = (): string =>
  join(
    process.env.XDG_STATE_HOME ?? join(homedir(), ".local", "state"),
    "pi-herdr",
    "review-boxes"
  );

const manifestKeyFor = (pr: PrInfo): string => {
  const url = new URL(pr.url);
  const repo = url.pathname.replace(/\/pull\/\d+\/?$/, "");
  return slugify(`${repo}-pr-${pr.number}`) || `pr-${pr.number}`;
};

const manifestPathFor = (pr: PrInfo, stateRoot: string): string =>
  join(stateRoot, `${manifestKeyFor(pr)}.json`);

export const isReviewBoxManifest = (value: unknown): value is ReviewBoxManifest =>
  isRecord(value) &&
  value.schemaVersion === 1 &&
  typeof value.repoRoot === "string" &&
  typeof value.prNumber === "number" &&
  typeof value.prUrl === "string" &&
  typeof value.headRefOid === "string" &&
  typeof value.worktreePath === "string" &&
  typeof value.workspaceId === "string" &&
  typeof value.diffTarget === "string" &&
  (value.agent === "omp" || value.agent === "pi") &&
  typeof value.updatedAt === "string";

const readManifest = async (path: string): Promise<ReviewBoxManifest | undefined> => {
  let content: string;
  try {
    content = await readFile(path, "utf8");
  } catch (error) {
    if (isRecord(error) && error.code === "ENOENT") return undefined;
    throw error;
  }
  try {
    const parsed: unknown = JSON.parse(content);
    if (!isReviewBoxManifest(parsed)) throw new Error(`invalid schema: ${path}`);
    return parsed;
  } catch {
    // Corrupt or wrong-schema manifest: back up to .bak, treat as absent.
    // (VAL-BRIDGE-014 / VAL-BRIDGE-035)
    await writeFile(`${path}.bak`, content).catch(() => {});
    await unlink(path).catch(() => {});
    return undefined;
  }
};

const writeManifest = async (path: string, manifest: ReviewBoxManifest): Promise<void> => {
  await mkdir(dirname(path), { recursive: true });
  const temporary = `${path}.${process.pid}.tmp`;
  await writeFile(temporary, `${JSON.stringify(manifest, null, 2)}\n`, { mode: 0o600 });
  await rename(temporary, path);
};

const workspaceExists = async (exec: ExecFn, workspaceId: string): Promise<boolean> =>
  runHerdr(exec, ["workspace", "get", workspaceId])
    .then(() => true)
    .catch(() => false);

const refreshCheckout = async (
  exec: ExecFn,
  repoRoot: string,
  worktreePath: string,
  baseRefName: string,
  prIdentifier: string,
  customBase: boolean
): Promise<void> => {
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
};

// ─── R2: Per-PR lockfile (node:fs only — no exec calls) ──────────────

const LOCK_POLL_MS = 100;
const LOCK_TIMEOUT_MS = 30_000;

const isPidAlive = (pid: number): boolean => {
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
};

/**
 * Acquire an O_EXCL per-PR lockfile in the review-boxes state dir.
 * A lock whose holder PID is dead is reclaimed (never deadlocks).
 * A live lock is never reclaimed — the caller polls until it is released
 * or the timeout expires.
 * Returns a release function that removes the lockfile.
 */
async function acquirePerPrLock(lockPath: string): Promise<() => Promise<void>> {
  await mkdir(dirname(lockPath), { recursive: true });

  const tryCreate = async (): Promise<boolean> => {
    try {
      await writeFile(lockPath, String(process.pid), { flag: "wx" });
      return true;
    } catch (err) {
      if (isRecord(err) && err.code === "EEXIST") return false;
      throw err;
    }
  };

  const tryReclaimStale = async (): Promise<boolean> => {
    try {
      const content = await readFile(lockPath, "utf8");
      const pid = parseInt(content.trim(), 10);
      if (Number.isNaN(pid) || !isPidAlive(pid)) {
        await unlink(lockPath).catch(() => {});
        return await tryCreate();
      }
      return false;
    } catch {
      // Lock file disappeared between EEXIST and read — try creating.
      return await tryCreate();
    }
  };

  if (await tryCreate()) {
    return () => unlink(lockPath).catch(() => {});
  }

  const deadline = Date.now() + LOCK_TIMEOUT_MS;
  while (Date.now() < deadline) {
    if (await tryReclaimStale()) {
      return () => unlink(lockPath).catch(() => {});
    }
    await new Promise((resolve) => setTimeout(resolve, LOCK_POLL_MS));
  }

  throw new Error(`per-PR lock timeout after ${LOCK_TIMEOUT_MS}ms: ${lockPath}`);
}

// ─── Exported gh fetch helper ────────────────────────────────────────

/**
 * Fetch PR info via `gh pr view`. Each caller makes exactly ONE gh call:
 * the Pi tool fetches without `state` (as today); the bridge fetches WITH
 * `state` for closed/merged revalidation, then passes the PrInfo through.
 */
export async function fetchPrInfo(
  exec: ExecFn,
  prIdentifier: string,
  opts?: {
    cwd?: string;
    timeout?: number;
    fields?: string[];
    repo?: string;
  }
): Promise<PrInfo> {
  const fields = opts?.fields ?? [
    "number",
    "title",
    "baseRefName",
    "headRefName",
    "headRefOid",
    "url",
  ];
  const args = ["pr", "view", prIdentifier, "--json", fields.join(",")];
  if (opts?.repo) args.push("--repo", opts.repo);
  const result = await runCommand(exec, "gh", args, {
    cwd: opts?.cwd ?? process.cwd(),
    timeout: opts?.timeout ?? 30_000,
  });
  return parsePrInfo(result.stdout);
}

// ─── Exported decision flow ──────────────────────────────────────────

/**
 * The full Review Box decision flow: manifest read, head-change detection,
 * workspace-exists / worktree-exists branches, and resume/refresh/restore/create.
 * Serialized by a per-PR O_EXCL lockfile (R2). Accepts a pre-fetched PrInfo
 * so each caller makes exactly ONE gh call.
 */
export async function openReviewBox(
  exec: ExecFn,
  opts: OpenReviewBoxOpts
): Promise<ReviewBoxResult> {
  const { pr, repoRoot, sharedRoot, prIdentifier } = opts;
  const stateRoot = opts.stateRoot ?? defaultStateRoot();
  const lockPath = join(stateRoot, `${manifestKeyFor(pr)}.lock`);
  const releaseLock = await acquirePerPrLock(lockPath);

  try {
    const manifestPath = manifestPathFor(pr, stateRoot);
    const manifest = await readManifest(manifestPath);
    const diffBase = opts.base ?? `origin/${pr.baseRefName}`;
    const diffTarget = `${diffBase}...HEAD`;
    const agent = opts.agent ?? manifest?.agent ?? "omp";

    // ── Branch 1: manifest matches repo + PR + worktree exists ──────
    if (
      manifest &&
      manifest.repoRoot === sharedRoot &&
      manifest.prNumber === pr.number &&
      (await pathExists(manifest.worktreePath))
    ) {
      const exists = await workspaceExists(exec, manifest.workspaceId);
      const headChanged = manifest.headRefOid !== pr.headRefOid;

      // ── Refresh: head changed ──
      if (headChanged) {
        await refreshCheckout(
          exec,
          repoRoot,
          manifest.worktreePath,
          pr.baseRefName,
          prIdentifier,
          Boolean(opts.base)
        );
        if (exists) await runHerdr(exec, ["workspace", "close", manifest.workspaceId]);
        const { workspaceId } = await createHerdrReviewWorkspace(exec, {
          worktreePath: manifest.worktreePath,
          prNumber: pr.number,
          title: pr.title,
          prUrl: pr.url,
          diffTarget,
          diffBase,
          extraPrompt: opts.prompt,
          agent,
        });
        await writeManifest(manifestPath, {
          ...manifest,
          headRefOid: pr.headRefOid,
          workspaceId,
          diffTarget,
          agent,
          updatedAt: new Date().toISOString(),
        });
        return {
          action: "refreshed",
          pr,
          worktreePath: manifest.worktreePath,
          workspaceId,
          diffTarget,
          agent,
        };
      }

      // ── Resume: workspace live, head unchanged ──
      if (exists) {
        await runHerdr(exec, ["workspace", "focus", manifest.workspaceId]);
        await writeManifest(manifestPath, {
          ...manifest,
          diffTarget,
          agent,
          updatedAt: new Date().toISOString(),
        });
        return {
          action: "resumed",
          pr,
          worktreePath: manifest.worktreePath,
          workspaceId: manifest.workspaceId,
          diffTarget,
          agent,
        };
      }

      // ── Restore: workspace gone, worktree still exists ──
      const { workspaceId } = await createHerdrReviewWorkspace(exec, {
        worktreePath: manifest.worktreePath,
        prNumber: pr.number,
        title: pr.title,
        prUrl: pr.url,
        diffTarget,
        diffBase,
        extraPrompt: opts.prompt,
        agent,
      });
      await writeManifest(manifestPath, {
        ...manifest,
        headRefOid: pr.headRefOid,
        workspaceId,
        diffTarget,
        agent,
        updatedAt: new Date().toISOString(),
      });
      return {
        action: "restored",
        pr,
        worktreePath: manifest.worktreePath,
        workspaceId,
        diffTarget,
        agent,
      };
    }

    // ── Branch 2: no manifest or mismatch — full create ────────────
    if (manifest && (await workspaceExists(exec, manifest.workspaceId))) {
      await runHerdr(exec, ["workspace", "close", manifest.workspaceId]);
    }

    const { worktreePath } = await prepareReviewWorktree(exec, {
      repoRoot,
      sharedRoot,
      prIdentifier,
      prNumber: pr.number,
      headRefName: pr.headRefName,
      baseRefName: pr.baseRefName,
      worktreeName: opts.worktreeName,
      base: opts.base,
    });

    const { workspaceId } = await createHerdrReviewWorkspace(exec, {
      worktreePath,
      prNumber: pr.number,
      title: pr.title,
      prUrl: pr.url,
      diffTarget,
      diffBase,
      extraPrompt: opts.prompt,
      agent,
    });
    await writeManifest(manifestPath, {
      schemaVersion: 1,
      repoRoot: sharedRoot,
      prNumber: pr.number,
      prUrl: pr.url,
      headRefOid: pr.headRefOid,
      worktreePath,
      workspaceId,
      diffTarget,
      agent,
      updatedAt: new Date().toISOString(),
    });
    return { action: "created", pr, worktreePath, workspaceId, diffTarget, agent };
  } finally {
    await releaseLock();
  }
}
