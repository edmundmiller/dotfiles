#!/usr/bin/env bun
import { Database } from "bun:sqlite";
import { readdir, realpath, stat } from "node:fs/promises";
import { basename, join, resolve } from "node:path";

const runtimes = ["omp", "pi", "hermes", "opencode"] as const;
type Runtime = (typeof runtimes)[number];

type Row = {
  updated: number;
  title: string;
  worktree: string;
  label: string;
  runtime: Runtime;
  token: string;
  cwd: string;
};

type Options = {
  worktrees: Map<string, string>;
  piAgentDir: string;
  ompAgentDir: string;
  hermesDb: string;
  opencodeBin: string;
};

type Json = Record<string, unknown>;
const labels: Record<Runtime, string> = {
  omp: "OMP",
  pi: "Pi",
  hermes: "Hermes",
  opencode: "OpenCode",
};
const priority = new Map(runtimes.map((runtime, index) => [runtime, index]));

function object(value: unknown): value is Json {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function text(value: unknown): string | undefined {
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function number(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

async function canonical(path: string): Promise<string | null> {
  try {
    return await realpath(path.replace(/\/+$/, "") || "/");
  } catch {
    return null;
  }
}

async function parseArgs(argv: string[]): Promise<Options> {
  if (argv.shift() !== "list") throw new Error("usage");
  const worktreeArgs: string[] = [];
  let piAgentDir = process.env.PI_CODING_AGENT_DIR ?? join(process.env.HOME ?? "", ".pi", "agent");
  let ompAgentDir = join(process.env.HOME ?? "", ".omp", "agent");
  let hermesDb = join(
    process.env.HERMES_HOME ?? join(process.env.HOME ?? "", ".hermes"),
    "state.db"
  );
  let opencodeBin = "opencode";
  while (argv.length) {
    const flag = argv.shift();
    const value = argv.shift();
    if (!value) throw new Error("usage");
    if (flag === "--worktree") worktreeArgs.push(value);
    else if (flag === "--pi-agent-dir") piAgentDir = value;
    else if (flag === "--omp-agent-dir") ompAgentDir = value;
    else if (flag === "--hermes-db") hermesDb = value;
    else if (flag === "--opencode-bin") opencodeBin = value;
    else throw new Error("usage");
  }
  if (!worktreeArgs.length) throw new Error("usage");
  const worktrees = new Map<string, string>();
  for (const path of worktreeArgs) {
    const cwd = await canonical(path);
    if (cwd) worktrees.set(cwd, basename(cwd));
  }
  if (!worktrees.size) throw new Error("usage");
  return { worktrees, piAgentDir, ompAgentDir, hermesDb, opencodeBin };
}

async function* files(directory: string): AsyncGenerator<string> {
  let entries;
  try {
    entries = await readdir(directory, { withFileTypes: true });
  } catch {
    return;
  }
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) yield* files(path);
    else if (entry.isFile() && entry.name.endsWith(".jsonl")) yield path;
  }
}

async function* lines(path: string): AsyncGenerator<string> {
  const decoder = new TextDecoder();
  let pending = "";
  for await (const chunk of Bun.file(path).stream()) {
    pending += decoder.decode(chunk, { stream: true });
    let newline;
    while ((newline = pending.indexOf("\n")) !== -1) {
      yield pending.slice(0, newline);
      pending = pending.slice(newline + 1);
    }
  }
  pending += decoder.decode();
  if (pending) yield pending;
}

async function jsonlRows(
  runtime: "pi" | "omp",
  agentDir: string,
  options: Options
): Promise<Row[]> {
  const rows: Row[] = [];
  for await (const path of files(join(agentDir, "sessions"))) {
    let header: Json | undefined;
    let name: string | undefined;
    let messages = 0;
    try {
      for await (const line of lines(path)) {
        if (!line.trim()) continue;
        const record: unknown = JSON.parse(line);
        if (!object(record)) continue;
        if (!header && record.type === "session") header = record;
        else if (record.type === "message") messages++;
        else if (record.type === "session_info" || record.type === "name")
          name = text(record.name) ?? text(record.title) ?? name;
      }
      const id = header && text(header.id);
      const rawCwd = header && text(header.cwd);
      if (!id || !rawCwd || !messages) continue;
      const cwd = await canonical(rawCwd);
      if (!cwd || !options.worktrees.has(cwd)) continue;
      const sessionPath = await realpath(resolve(path));
      rows.push({
        updated: (await stat(path)).mtimeMs,
        title: name ?? text(header.title) ?? text(header.name) ?? id.slice(0, 8),
        worktree: options.worktrees.get(cwd)!,
        label: labels[runtime],
        runtime,
        token: sessionPath,
        cwd,
      });
    } catch {
      // One damaged session must not hide healthy sessions.
    }
  }
  return rows;
}

type HermesSession = {
  id: string;
  source: string;
  config: Json;
  parent: string | null;
  started: number;
  ended: number | null;
  reason: string | null;
  cwd: string | null;
  title: string | null;
  archived: boolean;
  lastActive: number;
  messages: number;
};

function hermesRows(options: Options): Row[] {
  let db: Database;
  try {
    db = new Database(options.hermesDb, { readonly: true, create: false });
  } catch {
    return [];
  }
  try {
    const records = db
      .query(
        `
      SELECT s.id, s.source, s.model_config, s.parent_session_id, s.started_at, s.ended_at,
             s.end_reason, s.cwd, s.title, s.archived,
             COUNT(m.id) AS actual_messages, MAX(m.timestamp) AS message_last_active
      FROM sessions s LEFT JOIN messages m ON m.session_id = s.id
      GROUP BY s.id
    `
      )
      .all();
    const sessions = new Map<string, HermesSession>();
    for (const value of records) {
      if (!object(value)) continue;
      const id = text(value.id);
      const source = text(value.source);
      const started = number(value.started_at);
      if (!id || !source || started === undefined) continue;
      let config: unknown = {};
      try {
        config = JSON.parse(text(value.model_config) ?? "{}");
      } catch {
        /* invalid config is empty */
      }
      sessions.set(id, {
        id,
        source,
        config: object(config) ? config : {},
        parent: text(value.parent_session_id) ?? null,
        started,
        ended: number(value.ended_at) ?? null,
        reason: text(value.end_reason) ?? null,
        cwd: text(value.cwd) ?? null,
        title: text(value.title) ?? null,
        archived: value.archived === 1 || value.archived === true,
        lastActive: number(value.message_last_active) ?? started,
        messages: number(value.actual_messages) ?? 0,
      });
    }
    const children = new Map<string, HermesSession[]>();
    for (const session of sessions.values()) {
      if (!session.parent) continue;
      const siblings = children.get(session.parent) ?? [];
      siblings.push(session);
      children.set(session.parent, siblings);
    }
    const result: Row[] = [];
    for (const root of sessions.values()) {
      const parent = root.parent ? sessions.get(root.parent) : undefined;
      const branch =
        root.config._branched_from != null ||
        (parent?.reason === "branched" && parent.ended !== null && root.started >= parent.ended);
      if (
        root.archived ||
        !["cli", "tui"].includes(root.source) ||
        root.config._delegate_from != null ||
        (root.parent && !branch)
      )
        continue;
      const chain = [root];
      let current = root;
      let depth = 0;
      while (current.reason === "compression" && current.ended !== null && depth < 32) {
        depth++;
        const next = (children.get(current.id) ?? [])
          .filter((child) => child.started >= current.ended!)
          .sort((a, b) => b.started - a.started)[0];
        if (!next) break;
        chain.push(next);
        current = next;
      }
      while (current.messages === 0 && depth < 32) {
        depth++;
        const next = (children.get(current.id) ?? []).sort((a, b) => b.started - a.started)[0];
        if (!next) break;
        chain.push(next);
        current = next;
      }
      if (current.archived) continue;
      if (!chain.some((session) => session.messages > 0)) continue;
      const rawCwd = [...chain].reverse().find((session) => session.cwd)?.cwd;
      const title = [...chain].reverse().find((session) => session.title)?.title;
      if (!rawCwd) continue;
      result.push({
        updated: Math.max(...chain.map((session) => session.lastActive)) * 1000,
        title: title ?? current.id,
        worktree: rawCwd,
        label: labels.hermes,
        runtime: "hermes",
        token: current.id,
        cwd: rawCwd,
      });
    }
    return result;
  } catch {
    return [];
  } finally {
    db.close();
  }
}

async function canonicalizeHermes(rows: Row[], options: Options): Promise<Row[]> {
  const result: Row[] = [];
  for (const row of rows) {
    const cwd = await canonical(row.cwd);
    if (!cwd || !options.worktrees.has(cwd)) continue;
    result.push({ ...row, cwd, worktree: options.worktrees.get(cwd)! });
  }
  return result;
}

async function command(argv: string[]): Promise<string> {
  const process = Bun.spawn(argv, { stdout: "pipe", stderr: "ignore" });
  const output = await new Response(process.stdout).text();
  if ((await process.exited) !== 0) throw new Error("command failed");
  return output;
}

function tokenTotal(value: Json): number {
  const tokens = object(value.tokens) ? value.tokens : {};
  const cache = object(tokens.cache) ? tokens.cache : {};
  return [tokens.input, tokens.output, tokens.reasoning, cache.read, cache.write].reduce<number>(
    (sum, item) => sum + (number(item) ?? 0),
    0
  );
}

async function openCodeRows(options: Options): Promise<Row[]> {
  try {
    await command([options.opencodeBin, "service", "status"]);
    const rows = new Map<string, Row>();
    for (const directory of options.worktrees.keys()) {
      const seenCursors = new Set<string>();
      let cursor: string | undefined;
      do {
        const argv = [
          options.opencodeBin,
          "api",
          "GET",
          "/api/session",
          "--param",
          `directory=${directory}`,
        ];
        if (cursor) argv.push("--param", `cursor=${cursor}`);
        const envelope: unknown = JSON.parse(await command(argv));
        if (!object(envelope) || !Array.isArray(envelope.data)) throw new Error("invalid envelope");
        for (const value of envelope.data) {
          if (!object(value)) continue;
          const id = text(value.id);
          if (!id || text(value.parentID) || value.archived === true || tokenTotal(value) === 0)
            continue;
          const location = object(value.location) ? value.location : {};
          const rawCwd = text(location.directory);
          const time = object(value.time) ? value.time : {};
          const updated = number(time.updated);
          if (!rawCwd || updated === undefined || time.archived !== undefined) continue;
          const cwd = await canonical(rawCwd);
          if (!cwd || !options.worktrees.has(cwd)) continue;
          rows.set(id, {
            updated,
            title: text(value.title) ?? id,
            worktree: options.worktrees.get(cwd)!,
            label: labels.opencode,
            runtime: "opencode",
            token: id,
            cwd,
          });
        }
        const next = object(envelope.cursor) ? text(envelope.cursor.next) : undefined;
        if (!next || seenCursors.has(next)) break;
        seenCursors.add(next);
        cursor = next;
      } while (true);
    }
    return [...rows.values()];
  } catch {
    console.error("OpenCode sessions unavailable");
    return [];
  }
}

function flatten(value: string): string {
  return value.replace(/[\t\n\r]/g, " ");
}

function encode(value: string): string {
  return Buffer.from(value).toString("base64");
}

async function main(): Promise<void> {
  let options: Options;
  try {
    options = await parseArgs(process.argv.slice(2));
  } catch {
    console.error(
      "usage: agent-hunk-sessions.ts list --worktree <path>... [--pi-agent-dir <path>] [--omp-agent-dir <path>] [--hermes-db <path>] [--opencode-bin <path>]"
    );
    process.exitCode = 2;
    return;
  }
  const [omp, pi, hermes, opencode] = await Promise.all([
    jsonlRows("omp", options.ompAgentDir, options),
    jsonlRows("pi", options.piAgentDir, options),
    canonicalizeHermes(hermesRows(options), options),
    openCodeRows(options),
  ]);
  const rows = [...omp, ...pi, ...hermes, ...opencode].sort(
    (a, b) => b.updated - a.updated || priority.get(a.runtime)! - priority.get(b.runtime)!
  );
  for (const row of rows) {
    console.log(
      [
        new Date(row.updated).toISOString(),
        flatten(row.title),
        flatten(row.worktree),
        row.label,
        "resume",
        row.runtime,
        encode(row.token),
        encode(row.cwd),
      ].join("\t")
    );
  }
}

await main();
