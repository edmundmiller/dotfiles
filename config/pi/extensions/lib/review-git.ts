/**
 * review-git.ts - git helpers for the Pi-native review screen.
 */

import { existsSync } from "node:fs";
import path from "node:path";

export type ReviewMode = "worktree" | "staged";

export interface ExecResultLike {
  stdout: string;
  stderr: string;
  code: number;
  killed: boolean;
}

export interface ExecOptionsLike {
  cwd?: string;
  timeout?: number;
}

export interface ReviewExecutor {
  exec(command: string, args: string[], options?: ExecOptionsLike): Promise<ExecResultLike>;
}

export interface ReviewStatusEntry {
  path: string;
  oldPath?: string;
  x: string;
  y: string;
  raw: string;
  untracked: boolean;
}

export interface ReviewHunk {
  header: string;
  oldStartLine: number;
  newStartLine: number;
}

export interface ReviewFile {
  path: string;
  oldPath?: string;
  displayPath: string;
  status: string;
  statusSummary: string;
  diffText: string;
  added: number;
  removed: number;
  hunks: ReviewHunk[];
  absolutePath: string;
  openable: boolean;
}

export interface ReviewData {
  cwd: string;
  repoRoot: string;
  repoName: string;
  mode: ReviewMode;
  files: ReviewFile[];
}

function normalizePath(input: string): string {
  return input.replace(/^\.\//, "");
}

function parseStatusLine(line: string): ReviewStatusEntry | null {
  if (line.length < 3) return null;

  const x = line[0] ?? " ";
  const y = line[1] ?? " ";
  if (x === "!" && y === "!") return null;

  const rawPath = line.slice(3).trim();
  if (!rawPath) return null;

  if (x === "?" && y === "?") {
    return {
      path: normalizePath(rawPath),
      x,
      y,
      raw: line,
      untracked: true,
    };
  }

  const renameMarker = " -> ";
  const renameIndex = rawPath.indexOf(renameMarker);
  if (renameIndex !== -1) {
    const oldPath = normalizePath(rawPath.slice(0, renameIndex).trim());
    const newPath = normalizePath(rawPath.slice(renameIndex + renameMarker.length).trim());
    return {
      path: newPath,
      oldPath,
      x,
      y,
      raw: line,
      untracked: false,
    };
  }

  return {
    path: normalizePath(rawPath),
    x,
    y,
    raw: line,
    untracked: false,
  };
}

function includeEntry(entry: ReviewStatusEntry, mode: ReviewMode): boolean {
  if (entry.untracked) return mode === "worktree";
  if (mode === "staged") return entry.x !== " ";
  return entry.x !== " " || entry.y !== " ";
}

export function parseStatusPorcelain(text: string, mode: ReviewMode): ReviewStatusEntry[] {
  const lines = text.split("\n");
  const entries: ReviewStatusEntry[] = [];

  for (const line of lines) {
    if (!line.trim()) continue;
    const entry = parseStatusLine(line);
    if (!entry) continue;
    if (!includeEntry(entry, mode)) continue;
    entries.push(entry);
  }

  return entries;
}

function describeStatusLetter(letter: string): string {
  switch (letter) {
    case "M":
      return "modified";
    case "A":
      return "added";
    case "D":
      return "deleted";
    case "R":
      return "renamed";
    case "C":
      return "copied";
    case "T":
      return "type-changed";
    case "U":
      return "unmerged";
    case "?":
      return "untracked";
    default:
      return "changed";
  }
}

export function formatStatusCode(entry: ReviewStatusEntry): string {
  if (entry.untracked) return "??";
  const x = entry.x === " " ? "·" : entry.x;
  const y = entry.y === " " ? "·" : entry.y;
  return `${x}${y}`;
}

export function describeStatus(entry: ReviewStatusEntry): string {
  if (entry.untracked) return "untracked file";

  const parts: string[] = [];
  if (entry.x !== " ") parts.push(`staged ${describeStatusLetter(entry.x)}`);
  if (entry.y !== " ") parts.push(`unstaged ${describeStatusLetter(entry.y)}`);
  return parts.join(", ") || "changed";
}

export function extractHunks(diffText: string): ReviewHunk[] {
  const hunks: ReviewHunk[] = [];

  for (const line of diffText.split("\n")) {
    const match = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(line);
    if (!match) continue;

    const oldStartLine = Number(match[1]);
    const newStartLine = Number(match[2]);
    if (Number.isNaN(oldStartLine) || Number.isNaN(newStartLine)) continue;

    hunks.push({
      header: line,
      oldStartLine,
      newStartLine,
    });
  }

  return hunks;
}

export function countDiffStats(diffText: string): { added: number; removed: number } {
  let added = 0;
  let removed = 0;

  for (const line of diffText.split("\n")) {
    if (line.startsWith("+++")) continue;
    if (line.startsWith("---")) continue;
    if (line.startsWith("+")) added += 1;
    if (line.startsWith("-")) removed += 1;
  }

  return { added, removed };
}

export function chooseReviewEditor(env: NodeJS.ProcessEnv): string {
  const candidates = [env.PI_REVIEW_EDITOR, env.VISUAL, env.EDITOR];

  for (const candidate of candidates) {
    const trimmed = candidate?.trim();
    if (!trimmed) continue;
    if (trimmed === "true" || trimmed === ":" || trimmed === "cat") continue;
    return trimmed;
  }

  return "nvim";
}

function shellQuote(value: string): string {
  return `'${value.replace(/'/g, `'"'"'`)}'`;
}

export function buildEditorOpenCommand(editor: string, filePath: string, line: number): string {
  const safeLine = Math.max(1, line);
  const quotedPath = shellQuote(filePath);

  if (/(^|[\/\s])(code|cursor|codium|windsurf)\b/i.test(editor)) {
    const target = shellQuote(`${filePath}:${safeLine}`);
    return `${editor} --goto ${target}`;
  }

  if (/(^|[\/\s])(hx|helix)\b/i.test(editor)) {
    const target = shellQuote(`${filePath}:${safeLine}`);
    return `${editor} ${target}`;
  }

  return `${editor} +${safeLine} ${quotedPath}`;
}

async function runGit(
  executor: ReviewExecutor,
  cwd: string,
  args: string[],
  timeout: number = 15_000
): Promise<string> {
  const result = await executor.exec("git", ["-c", "core.quotePath=false", ...args], {
    cwd,
    timeout,
  });

  if (result.code !== 0) {
    const details = result.stderr.trim() || result.stdout.trim() || `git ${args.join(" ")} failed`;
    throw new Error(details);
  }

  return result.stdout;
}

async function loadUntrackedDiff(
  executor: ReviewExecutor,
  cwd: string,
  filePath: string
): Promise<string> {
  const result = await executor.exec(
    "git",
    ["diff", "--no-index", "--no-ext-diff", "--binary", "--", "/dev/null", filePath],
    {
      cwd,
      timeout: 15_000,
    }
  );

  if (result.code !== 0 && result.code !== 1) {
    const details = result.stderr.trim() || result.stdout.trim() || `git diff --no-index failed`;
    throw new Error(details);
  }

  return result.stdout.trim();
}

async function loadTrackedDiff(
  executor: ReviewExecutor,
  cwd: string,
  entry: ReviewStatusEntry,
  mode: ReviewMode
): Promise<string> {
  const baseArgs =
    mode === "staged"
      ? ["diff", "--cached", "--no-ext-diff", "--find-renames", "--binary"]
      : ["diff", "HEAD", "--no-ext-diff", "--find-renames", "--binary"];

  const primary = await runGit(executor, cwd, [...baseArgs, "--", entry.path]);
  if (primary.trim() || !entry.oldPath) return primary.trim();

  const fallback = await runGit(executor, cwd, [...baseArgs, "--", entry.oldPath]);
  return fallback.trim();
}

export async function loadReviewData(
  executor: ReviewExecutor,
  cwd: string,
  mode: ReviewMode
): Promise<ReviewData> {
  const repoRoot = (await runGit(executor, cwd, ["rev-parse", "--show-toplevel"], 5_000)).trim();
  const repoName = path.basename(repoRoot) || repoRoot;
  const statusText = await runGit(
    executor,
    cwd,
    ["status", "--porcelain=v1", "--untracked-files=all"],
    10_000
  );
  const entries = parseStatusPorcelain(statusText, mode);

  const files = await Promise.all(
    entries.map(async (entry) => {
      const diffText = entry.untracked
        ? await loadUntrackedDiff(executor, cwd, entry.path)
        : await loadTrackedDiff(executor, cwd, entry, mode);
      const finalDiffText = diffText.trim() || `No textual diff emitted by git for ${entry.path}.`;
      const { added, removed } = countDiffStats(finalDiffText);
      const hunks = extractHunks(finalDiffText);
      const absolutePath = path.resolve(cwd, entry.path);

      return {
        path: entry.path,
        oldPath: entry.oldPath,
        displayPath: entry.oldPath ? `${entry.oldPath} → ${entry.path}` : entry.path,
        status: formatStatusCode(entry),
        statusSummary: describeStatus(entry),
        diffText: finalDiffText,
        added,
        removed,
        hunks,
        absolutePath,
        openable: existsSync(absolutePath),
      } satisfies ReviewFile;
    })
  );

  return {
    cwd,
    repoRoot,
    repoName,
    mode,
    files,
  };
}
