import { constants } from "node:fs";
import { mkdtemp, open, readdir, realpath, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, extname, isAbsolute, join, relative, resolve, sep } from "node:path";
import { Worker } from "node:worker_threads";
import type { ThimbleJson } from "./thimble-json.js";

/** A source row keeps its upstream stable ref and its decoded JSON or text value. */
export interface ThimbleSourceRow {
  ref: string;
  raw: string;
  value: ThimbleJson;
}

/** Recoverable source size, parse, SQLite, and worker resource failures, not confinement or aborts. */
export class ThimbleSourceError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ThimbleSourceError";
  }
}

const sourceByteLimit = 64 * 1024 * 1024;
const responseByteLimit = 8 * 1024 * 1024;

/** Internal native worker request; SQLite paths refer only to disposable confined copies. */
export interface ThimbleSourceWork {
  file: string;
  kind: string;
  selector?: string;
  refs?: readonly string[];
  data?: Uint8Array;
  database?: string;
  responseByteLimit: number;
  operation: "read" | "count" | "sample";
  sample?: { rows: ThimbleSourceRow[]; matched: number; seed: number; limit: number };
}

/** Internal bounded worker response; count-only requests never return source rows. */
export interface ThimbleSourceResult {
  rows: ThimbleSourceRow[];
  matched: number;
  lines: number;
  seed: number;
}

const skipDirectories = new Set([
  ".git",
  ".hg",
  ".svn",
  "node_modules",
  "__pycache__",
  ".venv",
  "venv",
  ".mypy_cache",
  ".pytest_cache",
  ".thimble",
  "thimble",
  ".lite",
]);
const sourceExtensions = new Map([
  [".jsonl", "jsonl"],
  [".ndjson", "jsonl"],
  [".csv", "csv"],
  [".tsv", "csv"],
  [".json", "json"],
  [".db", "sqlite"],
  [".sqlite", "sqlite"],
  [".sqlite3", "sqlite"],
  [".md", "markdown"],
  [".markdown", "markdown"],
  [".rst", "markdown"],
  [".diff", "diff"],
  [".patch", "diff"],
]);
const textExtensions = new Set([
  ".txt",
  ".log",
  ".py",
  ".js",
  ".mjs",
  ".cjs",
  ".ts",
  ".tsx",
  ".jsx",
  ".sh",
  ".bash",
  ".zsh",
  ".yaml",
  ".yml",
  ".toml",
  ".ini",
  ".cfg",
  ".conf",
  ".html",
  ".css",
  ".sql",
  ".rb",
  ".go",
  ".rs",
  ".java",
  ".c",
  ".h",
  ".cpp",
  ".hpp",
  ".r",
  ".jl",
  ".lua",
  ".pl",
  ".php",
  ".swift",
  ".kt",
  ".scala",
  ".xml",
  ".srt",
  ".vtt",
  ".tex",
  ".bib",
  ".ipynb",
  ".env.example",
]);
const mediaExtensions = {
  pdf: [".pdf"],
  image: [
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".webp",
    ".bmp",
    ".tif",
    ".tiff",
    ".svg",
    ".ico",
    ".heic",
  ],
  audio: [".mp3", ".wav", ".m4a", ".flac", ".ogg", ".aac", ".opus"],
  video: [".mp4", ".mov", ".webm", ".mkv", ".avi", ".m4v"],
};

/** Classify by the final extension, without opening a file or detecting transcripts. */
export function thimbleSourceKind(file: string): string {
  const name = basename(file);
  const extension = extname(name).toLowerCase();
  const sourceKind = sourceExtensions.get(extension);
  if (sourceKind) return sourceKind;
  if (
    textExtensions.has(extension) ||
    (!extension && ["Makefile", "Dockerfile", "README", "LICENSE"].includes(name))
  ) {
    return "text";
  }
  return (
    Object.entries(mediaExtensions).find(([, extensions]) => extensions.includes(extension))?.[0] ??
    "file"
  );
}

function isSource(file: string): boolean {
  return !["pdf", "image", "audio", "video", "file"].includes(thimbleSourceKind(file));
}

class OutsideSourceError extends Error {
  constructor() {
    super("Thimble source is outside the working folder");
  }
}

function assertInsideRoot(root: string, path: string): void {
  const rel = relative(root, path);
  if (rel === ".." || rel.startsWith(`..${sep}`) || isAbsolute(rel)) throw new OutsideSourceError();
}

function isMissing(error: Error): boolean {
  return "code" in error && (error.code === "ENOENT" || error.code === "ENOTDIR");
}

async function readConfinedSource(
  root: string,
  file: string,
  budget: { remaining: number },
  signal?: AbortSignal
): Promise<{ data: Buffer; target: string }> {
  signal?.throwIfAborted();
  const realRoot = await realpath(root);
  const path = resolve(root, file);
  // Absolute paths may use another spelling of root, such as /var on macOS.
  if (!isAbsolute(file)) assertInsideRoot(resolve(root), path);
  const target = await realpath(path);
  assertInsideRoot(realRoot, target);
  const handle = await open(target, constants.O_RDONLY | constants.O_NOFOLLOW);
  try {
    const opened = await handle.stat();
    const current = await realpath(path);
    assertInsideRoot(await realpath(root), current);
    const expected = await stat(current);
    if (opened.dev !== expected.dev || opened.ino !== expected.ino) {
      throw new Error("Thimble source changed while opening the file");
    }
    if (!opened.isFile()) throw new Error("Thimble source is not a regular file");
    if (opened.size > budget.remaining) {
      throw new ThimbleSourceError("Thimble source exceeds the 64 MiB read budget");
    }
    const chunks: Buffer[] = [];
    let size = 0;
    for (;;) {
      signal?.throwIfAborted();
      // A one-byte probe at the budget boundary detects growth after stat.
      const chunk = Buffer.allocUnsafeSlow(Math.min(1024 * 1024, budget.remaining + 1));
      const { bytesRead } = await handle.read(chunk, 0, chunk.length, null);
      signal?.throwIfAborted();
      if (bytesRead > budget.remaining) {
        throw new ThimbleSourceError("Thimble source exceeds the 64 MiB read budget");
      }
      if (!bytesRead) break;
      budget.remaining -= bytesRead;
      size += bytesRead;
      chunks.push(chunk.subarray(0, bytesRead));
    }
    return { data: Buffer.concat(chunks, size), target };
  } finally {
    await handle.close();
  }
}

/** Read a literal filename (including #), confined and bounded to 64 MiB before and during reading. */
export async function readThimbleSource(
  root: string,
  file: string,
  signal?: AbortSignal
): Promise<Buffer> {
  return (await readConfinedSource(root, file, { remaining: sourceByteLimit }, signal)).data;
}

async function sourceStatus(root: string, file: string) {
  try {
    const target = await realpath(join(root, file));
    assertInsideRoot(await realpath(root), target);
    return await stat(target);
  } catch (error) {
    if (error instanceof Error && isMissing(error)) return undefined;
    throw error;
  }
}

/** List sorted visible files, omitting outward links and walking each directory inode once. */
export async function listThimbleFiles(root: string, signal?: AbortSignal): Promise<string[]> {
  const files: string[] = [];
  const walked = new Set<string>();
  async function walk(directory: string): Promise<void> {
    signal?.throwIfAborted();
    const info = await sourceStatus(root, directory);
    if (!info || walked.has(`${info.dev}:${info.ino}`)) return;
    walked.add(`${info.dev}:${info.ino}`);
    const entries = await readdir(join(root, directory), { withFileTypes: true });
    const directories: string[] = [];
    for (const entry of entries) {
      signal?.throwIfAborted();
      if (entry.name.startsWith(".") && !isSource(entry.name)) continue;
      if (skipDirectories.has(entry.name) && (entry.isDirectory() || entry.isSymbolicLink()))
        continue;
      const rel = directory ? `${directory}/${entry.name}` : entry.name;
      const status = await sourceStatus(root, rel).catch((error) => {
        if (error instanceof OutsideSourceError) return undefined;
        throw error;
      });
      if (status?.isDirectory()) {
        if (!entry.name.startsWith(".") && !skipDirectories.has(entry.name)) directories.push(rel);
      } else if (status?.isFile()) files.push(rel);
    }
    for (const directory of directories.sort()) await walk(directory);
  }
  await walk("");
  return files.sort();
}

function globSegment(pattern: string): RegExp {
  let expression = "";
  for (let i = 0; i < pattern.length; i++) {
    const char = pattern[i];
    if (char === "*") expression += ".*";
    else if (char === "?") expression += ".";
    else if (char === "[") {
      let end = i + 1;
      if (pattern[end] === "!") end++;
      if (pattern[end] === "]") end++;
      while (end < pattern.length && pattern[end] !== "]") end++;
      if (end === pattern.length) expression += "\\[";
      else {
        const body = pattern.slice(i + 1, end);
        expression += `[${body.startsWith("!") ? `^${body.slice(1)}` : body.replace(/^\^/, "\\^")}]`;
        i = end;
      }
    } else expression += char.replace(/[\\^$+?.()|{}\[\]]/g, "\\$&");
  }
  return new RegExp(`^${expression}$`, "u");
}

/** Expand Python-style *, ?, [], and ** globs; matching outward links are errors. */
export async function expandThimbleGlob(
  root: string,
  pattern: string,
  signal?: AbortSignal
): Promise<string[]> {
  pattern = pattern.trim();
  if (isAbsolute(pattern) || pattern.split("/").includes("..")) {
    throw new Error("Thimble label glob must stay inside the working folder");
  }
  const parts = pattern.split("/").filter((part) => part && part !== ".");
  if (!parts.length) return [];
  const files = new Set<string>();
  async function walk(
    directory: string,
    index: number,
    ancestors: ReadonlySet<string>
  ): Promise<void> {
    signal?.throwIfAborted();
    const info = await sourceStatus(root, directory);
    if (!info?.isDirectory()) return;
    const identity = `${info.dev}:${info.ino}:${index}`;
    if (ancestors.has(identity)) return;
    const nextAncestors = new Set([...ancestors, identity]);
    const part = parts[index];
    if (part === "**" && index + 1 < parts.length) await walk(directory, index + 1, nextAncestors);
    const matcher = globSegment(part);
    for (const entry of await readdir(join(root, directory), { withFileTypes: true })) {
      signal?.throwIfAborted();
      if (entry.name.startsWith(".") && (part === "**" || !part.startsWith("."))) continue;
      if (part !== "**" && !matcher.test(entry.name)) continue;
      if ((entry.isDirectory() || entry.isSymbolicLink()) && skipDirectories.has(entry.name))
        continue;
      const rel = directory ? `${directory}/${entry.name}` : entry.name;
      const status = await sourceStatus(root, rel);
      if (status?.isFile() && index === parts.length - 1) files.add(rel);
      if (
        status?.isDirectory() &&
        !entry.name.startsWith(".") &&
        !skipDirectories.has(entry.name)
      ) {
        if (part === "**") await walk(rel, index, nextAncestors);
        else if (index + 1 < parts.length) await walk(rel, index + 1, nextAncestors);
      }
    }
  }
  await walk("", 0, new Set());
  return [...files].sort();
}

function runSourceWorker(
  work: ThimbleSourceWork,
  signal?: AbortSignal
): Promise<ThimbleSourceResult> {
  // Bun cancels an AbortSignal.timeout timer when its last listener is removed.
  // Listen on a local composite so worker cleanup cannot consume a caller's
  // deadline before its next operation (for example regex labeling).
  if (signal) signal = AbortSignal.any([signal]);
  signal?.throwIfAborted();
  return new Promise((resolveResult, reject) => {
    const worker = new Worker(new URL("./thimble-source-worker.ts", import.meta.url), {
      workerData: work,
      transferList:
        work.data?.buffer instanceof ArrayBuffer &&
        work.data.buffer.byteLength === work.data.byteLength
          ? [work.data.buffer]
          : [],
      // Do not inherit Pi's loaders: this entry point uses only native modules.
      execArgv: process.versions.bun ? [] : ["--experimental-strip-types"],
      resourceLimits: { maxOldGenerationSizeMb: 256 },
    });
    let settled = false;
    let exited = false;
    const stopped = new Promise<void>((resolveExit) => {
      worker.once("exit", () => {
        exited = true;
        resolveExit();
      });
    });
    // Waiting for exit before resolving/rejecting also protects SQLite copy cleanup.
    const finish = async (error?: Error, result?: ThimbleSourceResult) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      signal?.removeEventListener("abort", abort);
      // Bun's terminate promise can remain pending if the worker already exited.
      // Observe the exit event itself rather than using that promise as a receipt.
      let terminationFailure: Error | undefined;
      if (!exited)
        void worker.terminate().catch((failure: Error) => {
          terminationFailure = failure;
        });
      await stopped;
      if (signal?.aborted) reject(signal.reason);
      else if (error || terminationFailure) reject(error ?? terminationFailure);
      else resolveResult(result!);
    };
    const abort = () => {
      void finish();
    };
    const timer = setTimeout(() => {
      void finish(new ThimbleSourceError("Thimble source worker exceeded 30 seconds"));
    }, 30_000);
    signal?.addEventListener("abort", abort, { once: true });
    worker.once(
      "message",
      (message: { error?: string; result?: ThimbleSourceResult; bytes?: number }) => {
        try {
          signal?.throwIfAborted();
          if (message.error) throw new ThimbleSourceError(message.error);
          if (
            !message.result ||
            message.bytes === undefined ||
            !Number.isInteger(message.bytes) ||
            message.bytes > responseByteLimit ||
            message.result.rows.length > 100_000
          ) {
            throw new ThimbleSourceError("Thimble source worker response exceeds the 8 MiB budget");
          }
          void finish(undefined, message.result);
        } catch (error) {
          void finish(error instanceof Error ? error : new Error(String(error)));
        }
      }
    );
    worker.once("error", (error) => {
      void finish(
        new ThimbleSourceError(
          `Thimble source worker failed: ${error instanceof Error ? error.message : String(error)}`
        )
      );
    });
    worker.once("exit", (code) => {
      void finish(
        new ThimbleSourceError(
          `Thimble source worker exited before returning a result (status ${code})`
        )
      );
    });
    if (signal?.aborted) abort();
  });
}

async function sourceWork(
  root: string,
  file: string,
  operation: ThimbleSourceWork["operation"],
  selector?: string,
  signal?: AbortSignal,
  sample?: ThimbleSourceWork["sample"],
  refs?: readonly string[]
): Promise<ThimbleSourceResult> {
  const budget = { remaining: sourceByteLimit };
  const { data, target } = await readConfinedSource(root, file, budget, signal);
  const kind = thimbleSourceKind(file);
  const work: ThimbleSourceWork = {
    file,
    kind,
    selector,
    refs,
    operation,
    sample,
    responseByteLimit,
  };
  if (kind !== "sqlite") return runSourceWorker({ ...work, data }, signal);
  const temporary = await mkdtemp(join(tmpdir(), "thimble-db-"));
  try {
    const database = join(temporary, "db");
    await writeFile(database, data, { signal });
    try {
      // The real DB target determines WAL adjacency; refs retain the caller's alias.
      // Independently authorize the WAL, including a possible outward WAL symlink.
      const wal = await readConfinedSource(root, `${target}-wal`, budget, signal);
      if (wal.data.length) await writeFile(`${database}-wal`, wal.data, { signal });
    } catch (error) {
      if (!(error instanceof Error && isMissing(error))) throw error;
    }
    return await runSourceWorker({ ...work, database }, signal);
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}

/** Read upstream rows off the main loop, optionally by ref; responses have an 8 MiB/100,000-row limit. */
export async function readThimbleRows(
  root: string,
  file: string,
  selector?: string,
  signal?: AbortSignal,
  refs?: readonly string[]
): Promise<ThimbleSourceRow[]> {
  return (await sourceWork(root, file, "read", selector, signal, undefined, refs)).rows;
}

/** Count source rows (estimated pages for PDFs) and physical LF lines in a worker, without returning rows. */
export async function countThimbleSourceRows(
  root: string,
  file: string,
  signal?: AbortSignal
): Promise<{ rows: number; lines: number }> {
  const result = await sourceWork(root, file, "count", undefined, signal);
  return { rows: result.matched, lines: result.lines };
}

/** Sample up to 100 rows using the label engine's deterministic cross-file reservoir, in workers. */
export async function sampleThimbleRows(
  root: string,
  files: readonly string[],
  selector: string | undefined,
  limit: number,
  signal?: AbortSignal
): Promise<{ rows: ThimbleSourceRow[]; matched: number }> {
  signal?.throwIfAborted();
  if (!Number.isInteger(limit) || limit < 1 || limit > 100)
    throw new Error("Thimble source sample limit must be between 1 and 100");
  let state: NonNullable<ThimbleSourceWork["sample"]> = {
    rows: [],
    matched: 0,
    seed: 0x6d2b79f5,
    limit,
  };
  for (const file of files) {
    const result = await sourceWork(root, file, "sample", selector, signal, state);
    state = { rows: result.rows, matched: result.matched, seed: result.seed, limit };
  }
  signal?.throwIfAborted();
  return { rows: state.rows, matched: state.matched };
}
