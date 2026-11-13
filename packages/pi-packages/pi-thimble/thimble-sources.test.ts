import { afterEach, beforeEach, expect, test } from "bun:test";
import { Database } from "bun:sqlite";
import {
  mkdir,
  mkdtemp,
  readFile,
  readdir,
  realpath,
  rm,
  stat,
  symlink,
  truncate,
  unlink,
  writeFile,
} from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";
import { pathToFileURL } from "node:url";
import { setTimeout as delay } from "node:timers/promises";
import { loadThimbleLabels, runThimbleLabel } from "./thimble-labels.js";
import {
  countThimbleSourceRows,
  expandThimbleGlob,
  listThimbleFiles,
  readThimbleRows,
  readThimbleSource,
  sampleThimbleRows,
  ThimbleSourceError,
  thimbleSourceKind,
} from "./thimble-sources.js";

let root: string;
let outside: string;
beforeEach(async () => {
  root = await mkdtemp(join(tmpdir(), "thimble-sources-"));
  outside = await mkdtemp(join(tmpdir(), "thimble-outside-"));
});
afterEach(async () => {
  await rm(root, { recursive: true, force: true });
  await rm(outside, { recursive: true, force: true });
});

test("JSONL retains physical line refs, malformed records, and original whitespace", async () => {
  await writeFile(join(root, "chat.ndjson"), '  {"text":"café"} \r\n\r\nnot JSON\nfalse\n');
  expect(await readThimbleRows(root, "chat.ndjson")).toEqual([
    { ref: "chat.ndjson#L1", raw: '  {"text":"café"} ', value: { text: "café" } },
    { ref: "chat.ndjson#L3", raw: "not JSON", value: { _text: "not JSON" } },
    { ref: "chat.ndjson#L4", raw: "false", value: false },
  ]);
});

test("CSV parses quoted multiline fields, escaped quotes, missing and excess columns", async () => {
  await writeFile(
    join(root, "data.csv"),
    'who,note\r\nAda,"first, line\r\nsecond ""quote"""\r\n\r\nBen\r\nCy,ok,extra,tail\r\n'
  );
  expect(await readThimbleRows(root, "data.csv")).toEqual([
    {
      ref: "data.csv#row=1",
      raw: '{"who": "Ada", "note": "first, line\\r\\nsecond \\"quote\\""}',
      value: { who: "Ada", note: 'first, line\r\nsecond "quote"' },
    },
    {
      ref: "data.csv#row=2",
      raw: '{"who": "Ben", "note": null}',
      value: { who: "Ben", note: null },
    },
    {
      ref: "data.csv#row=3",
      raw: '{"who": "Cy", "note": "ok", "null": ["extra", "tail"]}',
      value: { who: "Cy", note: "ok", null: ["extra", "tail"] },
    },
  ]);
  await writeFile(join(root, "data.TSV"), 'id\ttext\n7\t"tab\tinside\nand next line"\n');
  expect((await readThimbleRows(root, "data.TSV"))[0]).toEqual({
    ref: "data.TSV#row=1",
    raw: '{"id": "7", "text": "tab\\tinside\\nand next line"}',
    value: { id: "7", text: "tab\tinside\nand next line" },
  });
});

test("JSON chooses the first longest top-level list before considering nested lists", async () => {
  await writeFile(
    join(root, "items.json"),
    '{"nested":{"long":[1,2,3]},"a/b":[{"n":7},false],"tie":[8,9]}'
  );
  expect(await readThimbleRows(root, "items.json")).toEqual([
    { ref: "items.json#/a~1b/0", raw: '{"n": 7}', value: { n: 7 } },
    { ref: "items.json#/a~1b/1", raw: "false", value: false },
  ]);
  await writeFile(join(root, "nested.json"), '{"empty":[],"wrap":{"rows":[4,5]}}');
  expect((await readThimbleRows(root, "nested.json")).map((row) => row.ref)).toEqual([
    "nested.json#/wrap/rows/0",
    "nested.json#/wrap/rows/1",
  ]);
  await writeFile(join(root, "empty.json"), '{"rows":[]}');
  expect(await readThimbleRows(root, "empty.json")).toEqual([
    { ref: "empty.json#/", raw: '{"rows": []}', value: { rows: [] } },
  ]);
});

test("JSON wildcard pointers expand lists and objects, escape refs, and skip absent branches", async () => {
  await writeFile(
    join(root, "runs.json"),
    '{"a/b":{"messages":["first",{"text":"second"}]},"~last":{"messages":"single"},"skip":{}}'
  );
  expect(await readThimbleRows(root, "runs.json", "#/*/messages")).toEqual([
    { ref: "runs.json#/a~1b/messages/0", raw: '"first"', value: "first" },
    { ref: "runs.json#/a~1b/messages/1", raw: '{"text": "second"}', value: { text: "second" } },
    { ref: "runs.json#/~0last/messages", raw: '"single"', value: "single" },
  ]);
  expect((await readThimbleRows(root, "runs.json", "/a~1b/messages/01/text"))[0]?.ref).toBe(
    "runs.json#/a~1b/messages/01/text"
  );
  expect(await readThimbleRows(root, "runs.json", "/missing")).toEqual([]);
  expect((await readThimbleRows(root, "runs.json", "/"))[0]?.ref).toBe("runs.json#/");
});

test("Worker transport preserves negative zero values instead of reparsing serialized JSON", async () => {
  await writeFile(join(root, "numbers.json"), "[-0, 0]");
  const rows = await readThimbleRows(root, "numbers.json");
  expect(rows.map((row) => row.raw)).toEqual(["0", "0"]);
  expect(Object.is(rows[0].value, -0)).toBe(true);
  expect(Object.is(rows[1].value, 0)).toBe(true);
});

test("Markdown sections include preambles and original heading ranges", async () => {
  await writeFile(join(root, "note.md"), "Intro\n\n# First\nbody\n## Second\nlast\n");
  expect(await readThimbleRows(root, "note.md")).toEqual([
    { ref: "note.md#L1-2", raw: "Intro\n", value: { heading: "", level: 0, text: "Intro\n" } },
    {
      ref: "note.md#L3-4",
      raw: "# First\nbody",
      value: { heading: "First", level: 1, text: "# First\nbody" },
    },
    {
      ref: "note.md#L5-6",
      raw: "## Second\nlast",
      value: { heading: "Second", level: 2, text: "## Second\nlast" },
    },
  ]);
});

test("Diff hunks stop at file boundaries, retain ranges and count added and removed lines", async () => {
  await writeFile(
    join(root, "change.patch"),
    "--- a/one\n+++ b/one\n@@ -2,2 +3,3 @@ title\n-old\n+new\n+more\n same\n\n--- a/two\n+++ b/two\n@@ -1 +1 @@\n-before\n+after\n"
  );
  expect(await readThimbleRows(root, "change.patch")).toEqual([
    {
      ref: "change.patch#L3-7",
      raw: "@@ -2,2 +3,3 @@ title\n-old\n+new\n+more\n same",
      value: {
        file: "one",
        header: "@@ -2,2 +3,3 @@ title",
        old_start: 2,
        new_start: 3,
        added: 2,
        removed: 1,
        text: "@@ -2,2 +3,3 @@ title\n-old\n+new\n+more\n same",
      },
    },
    {
      ref: "change.patch#L11-13",
      raw: "@@ -1 +1 @@\n-before\n+after",
      value: {
        file: "two",
        header: "@@ -1 +1 @@",
        old_start: 1,
        new_start: 1,
        added: 1,
        removed: 1,
        text: "@@ -1 +1 @@\n-before\n+after",
      },
    },
  ]);
});

test("Text keeps blank lines but does not invent a line after a terminal newline", async () => {
  await writeFile(join(root, "run.log"), "first\r\n\r\nlast");
  expect(await readThimbleRows(root, "run.log")).toEqual([
    { ref: "run.log#L1", raw: "first", value: "first" },
    { ref: "run.log#L2", raw: "", value: "" },
    { ref: "run.log#L3", raw: "last", value: "last" },
  ]);
  await writeFile(join(root, "empty.txt"), "");
  expect(await readThimbleRows(root, "empty.txt")).toEqual([]);
});

test("File kinds distinguish source and media suffixes without treating arbitrary files as text", () => {
  expect(
    [
      "A.NDJSON",
      "x.TSV",
      "x.sqlite3",
      "x.rst",
      "x.patch",
      "README",
      "x.PDF",
      "x.svg",
      "x.opus",
      "x.m4v",
      "x.zip",
      ".bashrc",
    ].map(thimbleSourceKind)
  ).toEqual([
    "jsonl",
    "csv",
    "sqlite",
    "markdown",
    "diff",
    "text",
    "pdf",
    "image",
    "audio",
    "video",
    "file",
    "file",
  ]);
});

test("Listing skips dependency and hidden directories, includes hidden sources and breaks link cycles", async () => {
  for (const directory of ["data", "node_modules", ".hidden", "thimble"]) {
    await mkdir(join(root, directory));
    await writeFile(join(root, directory, "in.txt"), "row");
  }
  await writeFile(join(root, ".records.jsonl"), "{}");
  await writeFile(join(root, ".secret"), "hidden");
  await writeFile(join(root, "photo.png"), "image");
  await symlink(root, join(root, "data", "loop"));
  await symlink(join(root, "missing"), join(root, "broken"));
  expect(await listThimbleFiles(root)).toEqual([".records.jsonl", "data/in.txt", "photo.png"]);
  expect(await expandThimbleGlob(root, "  ./**/*.txt  ")).toEqual(["data/in.txt"]);
  expect(await expandThimbleGlob(root, "data/i?.[t]xt")).toEqual(["data/in.txt"]);
  expect(await expandThimbleGlob(root, "*.jsonl")).toEqual([]);
  expect(await expandThimbleGlob(root, ".*.jsonl")).toEqual([".records.jsonl"]);
});

test("Literal hash filenames are not selectors and link replacement cannot reuse stale confinement", async () => {
  await writeFile(join(root, "inside.txt"), "safe");
  await writeFile(join(outside, "secret.txt"), "outside secret");
  const link = join(root, "report#part.txt");
  await symlink(join(root, "inside.txt"), link);
  expect((await readThimbleSource(root, "report#part.txt")).toString()).toBe("safe");
  await unlink(link);
  await symlink(join(outside, "secret.txt"), link);
  await expect(readThimbleSource(root, "report#part.txt")).rejects.toThrow(
    "outside the working folder"
  );
  await expect(readThimbleRows(root, "report#part.txt")).rejects.toThrow(
    "outside the working folder"
  );
  await expect(expandThimbleGlob(root, "  report#*.txt ")).rejects.toThrow(
    "outside the working folder"
  );
  expect(await listThimbleFiles(root)).toEqual(["inside.txt"]);
  expect(await expandThimbleGlob(root, "inside.txt")).toEqual(["inside.txt"]);
});

test("Canonical roots accept confined absolute aliases without accepting outward aliases or traversal", async () => {
  const canonicalRoot = await realpath(root);
  const alias = join(outside, "root-alias");
  await symlink(canonicalRoot, alias);
  await writeFile(join(root, "record#one.txt"), "visible line\n");
  await writeFile(join(outside, "secret.txt"), "outside secret");
  await symlink(join(outside, "secret.txt"), join(root, "escape.txt"));
  expect((await readThimbleSource(canonicalRoot, join(alias, "record#one.txt"))).toString()).toBe(
    "visible line\n"
  );
  expect((await readThimbleRows(canonicalRoot, join(alias, "record#one.txt")))[0]?.value).toBe(
    "visible line"
  );
  await expect(readThimbleSource(canonicalRoot, join(alias, "escape.txt"))).rejects.toThrow(
    "outside the working folder"
  );
  await expect(
    readThimbleSource(canonicalRoot, relative(canonicalRoot, join(outside, "secret.txt")))
  ).rejects.toThrow("outside the working folder");
  await expect(readThimbleSource(canonicalRoot, join(alias, "..", "secret.txt"))).rejects.toThrow(
    "outside the working folder"
  );
});

test("Outward directory symlinks and traversal globs are rejected", async () => {
  await writeFile(join(outside, "data.json"), "[1]");
  await symlink(outside, join(root, "dataset"));
  await expect(readThimbleSource(root, "dataset/data.json")).rejects.toThrow(
    "outside the working folder"
  );
  await expect(expandThimbleGlob(root, "dataset/*.json")).rejects.toThrow(
    "outside the working folder"
  );
  await expect(expandThimbleGlob(root, "**/*.json")).rejects.toThrow("outside the working folder");
  await expect(expandThimbleGlob(root, "../*.json")).rejects.toThrow("inside the working folder");
  await expect(expandThimbleGlob(root, `${outside}/*.json`)).rejects.toThrow(
    "inside the working folder"
  );
});

test("SQLite reads uncheckpointed WAL rows, table selectors and blobs without changing source files", async () => {
  const path = join(root, "events.db");
  const database = new Database(path);
  try {
    database.exec(
      "pragma journal_mode=WAL; pragma wal_autocheckpoint=0; create table z (note text); create table a (n integer, payload blob); create table noid (id text primary key) without rowid;"
    );
    database.exec(
      "insert into a (rowid,n,payload) values (7,42,x'610aff'); insert into z values ('last'); insert into noid values ('skip');"
    );
    const names = (await readdir(root)).sort();
    const before = await Promise.all(
      names.map(async (name) => ({
        name,
        data: await readFile(join(root, name)),
        mtime: (await stat(join(root, name))).mtimeMs,
      }))
    );
    expect(await readThimbleRows(root, "events.db")).toEqual([
      {
        ref: "events.db#a/7",
        raw: '{"n": 42, "payload": "b\'a\\\\n\\\\xff\'"}',
        value: { n: 42, payload: "b'a\\n\\xff'" },
      },
      { ref: "events.db#z/1", raw: '{"note": "last"}', value: { note: "last" } },
    ]);
    expect((await readThimbleRows(root, "events.db", "z")).map((row) => row.ref)).toEqual([
      "events.db#z/1",
    ]);
    expect((await readdir(root)).sort()).toEqual(names);
    for (const file of before) {
      expect(await readFile(join(root, file.name))).toEqual(file.data);
      expect((await stat(join(root, file.name))).mtimeMs).toBe(file.mtime);
    }
  } finally {
    database.close();
  }
});

test("SQLite keeps 64-bit rowids exact in refs and raw JSON", async () => {
  const database = new Database(join(root, "large.db"));
  database.exec(
    "create table data (id integer primary key, text text); insert into data values (9007199254740993, 'large')"
  );
  database.close();
  const rows = await readThimbleRows(root, "large.db");
  expect(rows).toHaveLength(1);
  expect(rows[0].ref).toBe("large.db#data/9007199254740993");
  expect(rows[0].raw).toBe('{"id": 9007199254740993, "text": "large"}');
});

test("Selectors reject incompatible source kinds and distinguish absent tables from empty tables", async () => {
  await writeFile(join(root, "data.jsonl"), '{"value":1}\n');
  await writeFile(join(root, "data.json"), '[{"value":1}]');
  const database = new Database(join(root, "tables.db"));
  database.exec(
    "create table empty (value text); create table populated (value text); insert into populated values ('present')"
  );
  database.close();
  await expect(readThimbleRows(root, "data.jsonl", "/value")).rejects.toThrow(
    "is no JSON document"
  );
  await expect(readThimbleRows(root, "tables.db", "/value")).rejects.toThrow("is no JSON document");
  await expect(readThimbleRows(root, "data.json", "some_table")).rejects.toThrow("has no table");
  await expect(readThimbleRows(root, "data.jsonl", "some_table")).rejects.toThrow("has no table");
  await expect(readThimbleRows(root, "tables.db", "absent")).rejects.toThrow(
    'has no table "absent"; its tables: empty, populated'
  );
  expect(await readThimbleRows(root, "tables.db", "empty")).toEqual([]);
  expect((await readThimbleRows(root, "tables.db", "populated"))[0]?.value).toEqual({
    value: "present",
  });
});

test("SQLite WAL paths are confined too", async () => {
  const database = new Database(join(root, "plain.db"));
  database.exec("create table data (value text); insert into data values ('ok')");
  database.close();
  await writeFile(join(outside, "wal"), "not a real WAL");
  await symlink(join(outside, "wal"), join(root, "plain.db-wal"));
  await expect(readThimbleRows(root, "plain.db")).rejects.toThrow("outside the working folder");
});

test("Source operations honor already-aborted signals", async () => {
  const signal = AbortSignal.abort(new Error("stop source work"));
  await expect(readThimbleSource(root, "missing.txt", signal)).rejects.toThrow("stop source work");
  await expect(readThimbleRows(root, "missing.txt", undefined, signal)).rejects.toThrow(
    "stop source work"
  );
  await expect(listThimbleFiles(root, signal)).rejects.toThrow("stop source work");
  await expect(expandThimbleGlob(root, "**", signal)).rejects.toThrow("stop source work");
});

test("Finishing a worker does not consume the caller's deadline for later work", async () => {
  await writeFile(join(root, "small.txt"), "one\n");
  const signal = AbortSignal.timeout(100);
  expect((await sampleThimbleRows(root, ["small.txt"], undefined, 1, signal)).matched).toBe(1);
  await expect(delay(250, undefined, { signal })).rejects.toThrow();
  expect(signal.aborted).toBe(true);
});

test("A large valid CSV is cancelled by a main-loop timer before parsing can complete", async () => {
  // This is below the source budget but expensive enough that synchronous CSV
  // decoding used to finish before the abort timer could run.
  await writeFile(join(root, "large.csv"), "text\n" + `"${"x".repeat(120)}"\n`.repeat(180_000));
  const directory = join(outside, "labels");
  for (const operation of [
    (signal: AbortSignal) => readThimbleRows(root, "large.csv", undefined, signal),
    (signal: AbortSignal) =>
      runThimbleLabel(
        root,
        directory,
        "cancel",
        {
          action: "prompt",
          name: "cancelled",
          glob: "large.csv",
          rule: "classify text",
          limit: 1,
        },
        signal
      ),
  ]) {
    const controller = new AbortController();
    const reason = new Error("cancel large CSV on the main loop");
    let timerElapsed = 0;
    const start = performance.now();
    const timer = setTimeout(() => {
      timerElapsed = performance.now() - start;
      controller.abort(reason);
    }, 100);
    try {
      await expect(operation(controller.signal)).rejects.toBe(reason);
      expect(timerElapsed).toBeGreaterThan(0);
      expect(timerElapsed).toBeLessThan(500);
      expect(performance.now() - start).toBeLessThan(1500);
    } finally {
      clearTimeout(timer);
    }
  }
  expect(await loadThimbleLabels(directory)).toEqual([]);
}, 4000);

test("Pre-read budgets reject oversized sparse sources and combined SQLite/WAL bytes", async () => {
  const oversized = join(root, "oversized.csv");
  await writeFile(oversized, "text\n");
  await truncate(oversized, 64 * 1024 * 1024 + 1);
  await expect(readThimbleSource(root, "oversized.csv")).rejects.toBeInstanceOf(ThimbleSourceError);
  await expect(readThimbleRows(root, "oversized.csv")).rejects.toThrow("64 MiB read budget");
  const database = new Database(join(root, "budget.db"));
  database.exec("create table data (n integer)");
  database.close();
  await writeFile(join(root, "budget.db-wal"), "");
  await truncate(join(root, "budget.db-wal"), 64 * 1024 * 1024);
  await expect(countThimbleSourceRows(root, "budget.db")).rejects.toThrow("64 MiB read budget");
});

test("Sampling and counting return bounded results even when a full row response exceeds its budget", async () => {
  // Each file alone expands past 8 MiB on the wire, while three sampled rows fit.
  const body = ("x".repeat(500) + "\n").repeat(10_000);
  await writeFile(join(root, "a.txt"), body);
  await writeFile(join(root, "b.txt"), body);
  await expect(readThimbleRows(root, "a.txt")).rejects.toThrow("8 MiB budget");
  expect(await countThimbleSourceRows(root, "a.txt")).toEqual({ rows: 10_000, lines: 10_000 });
  const sample = await sampleThimbleRows(root, ["a.txt", "b.txt"], undefined, 3);
  expect(sample.matched).toBe(20_000);
  expect(sample.rows).toHaveLength(3);
  // Fixed outputs of the old reservoir recurrence, independent of the new worker.
  expect(sample.rows.map((row) => row.ref)).toEqual(["a.txt#L3141", "b.txt#L3092", "b.txt#L7661"]);
  expect(sample.rows.every((row) => row.raw.length === 500)).toBe(true);
  const labels = join(outside, "labels");
  const created = await runThimbleLabel(root, labels, "sampling", {
    action: "prompt",
    name: "bounded",
    glob: "*.txt",
    rule: "classify text",
    limit: 3,
  });
  expect(created).toMatchObject({ records: 3, added: 3 });
  const [saved] = await loadThimbleLabels(labels);
  expect(saved.matched).toBe(20_000);
  expect(Object.keys(saved.units)).toEqual(sample.rows.map((row) => row.ref));
  expect(
    await runThimbleLabel(root, labels, "sampling", { action: "records", name: "bounded" })
  ).toMatchObject({
    total: 3,
    records: [{ ref: "a.txt#L3141" }, { ref: "b.txt#L3092" }, { ref: "b.txt#L7661" }],
  });
  expect(
    await runThimbleLabel(root, labels, "sampling", { action: "waiting", name: "bounded" })
  ).toMatchObject({
    waiting: 3,
    units: [{ ref: "a.txt#L3141" }, { ref: "b.txt#L3092" }, { ref: "b.txt#L7661" }],
  });
});

test("A sampled row cannot exceed the response budget, and row counts do not transfer it", async () => {
  await writeFile(join(root, "wide.json"), JSON.stringify(["x".repeat(5 * 1024 * 1024)]));
  await expect(sampleThimbleRows(root, ["wide.json"], undefined, 1)).rejects.toThrow(
    "8 MiB budget"
  );
  expect(await countThimbleSourceRows(root, "wide.json")).toEqual({ rows: 1, lines: 1 });
});

test("Count failures distinguish recoverable parsing from confinement and cancellation", async () => {
  await writeFile(join(root, "broken.json"), "[");
  await expect(countThimbleSourceRows(root, "broken.json")).rejects.toBeInstanceOf(
    ThimbleSourceError
  );
  await writeFile(join(outside, "secret.json"), "[1]");
  await symlink(join(outside, "secret.json"), join(root, "escape.json"));
  try {
    await countThimbleSourceRows(root, "escape.json");
    throw new Error("Outward source unexpectedly counted");
  } catch (error) {
    expect(error).not.toBeInstanceOf(ThimbleSourceError);
    expect(String(error)).toContain("outside the working folder");
  }
  const reason = new Error("cancel count");
  await expect(countThimbleSourceRows(root, "broken.json", AbortSignal.abort(reason))).rejects.toBe(
    reason
  );
  await writeFile(join(root, "lines.jsonl"), "{}\r\n\r\nfalse\n");
  expect(await countThimbleSourceRows(root, "lines.jsonl")).toEqual({ rows: 2, lines: 3 });
});

test("Worker errors, early exits and cancellation remove SQLite copies after the worker stops", async () => {
  const database = new Database(join(root, "fixture.db"));
  database.exec("create table data (n integer); insert into data values (7)");
  database.close();
  // Isolate failure injection in a private adapter copy, never mutate the shared
  // worker used by other tests. Type-only imports need no runtime dependencies.
  const source = await readFile(new URL("./thimble-sources.ts", import.meta.url), "utf8");
  for (const mode of ["throw", "exit", "cancel"]) {
    const fixture = join(outside, mode);
    await mkdir(fixture);
    await writeFile(join(fixture, "thimble-sources.ts"), source);
    const marker = join(fixture, "opened-copy");
    await writeFile(
      join(fixture, "thimble-source-worker.ts"),
      `
      import { workerData } from "node:worker_threads";
      import { writeFileSync, existsSync } from "node:fs";
      writeFileSync(${JSON.stringify(marker)}, workerData.database);
      ${
        mode === "throw"
          ? 'throw new Error("injected worker failure");'
          : mode === "exit"
            ? "process.exit(0);"
            : `
        // Detect deletion while still alive, not just eventual cleanup.
        for (;;) {
          if (!existsSync(workerData.database)) writeFileSync(${JSON.stringify(join(fixture, "deleted-too-early"))}, "bad");
        }
      `
      }
    `
    );
    const adapter: typeof import("./thimble-sources.js") = await import(
      pathToFileURL(join(fixture, "thimble-sources.ts")).href
    );
    const controller = new AbortController();
    const reason = new Error("stop injected worker");
    const pending = adapter.readThimbleRows(root, "fixture.db", undefined, controller.signal);
    // Attach rejection observation immediately; it may fail before marker polling.
    const outcome = pending.then(
      () => undefined,
      (error: Error) => error
    );
    for (let i = 0; i < 200; i++) {
      if (
        await stat(marker).then(
          () => true,
          () => false
        )
      )
        break;
      await delay(5);
    }
    const copy = await readFile(marker, "utf8");
    if (mode === "cancel") controller.abort(reason);
    const error = await outcome;
    if (mode === "cancel") expect(error).toBe(reason);
    else expect(error).toBeInstanceOf(adapter.ThimbleSourceError);
    expect(
      await stat(copy).then(
        () => true,
        () => false
      )
    ).toBe(false);
    expect(
      await stat(join(fixture, "deleted-too-early")).then(
        () => true,
        () => false
      )
    ).toBe(false);
  }
});

test("A confined SQLite alias uses the real DB's uncheckpointed WAL but retains alias refs", async () => {
  const database = new Database(join(root, "actual.db"));
  try {
    database.exec(
      "pragma journal_mode=WAL; pragma wal_autocheckpoint=0; create table data (note text); insert into data values ('uncheckpointed')"
    );
    await symlink(join(root, "actual.db"), join(root, "alias.db"));
    const dbBefore = await readFile(join(root, "actual.db"));
    const walBefore = await readFile(join(root, "actual.db-wal"));
    expect(await readThimbleRows(root, "alias.db")).toEqual([
      {
        ref: "alias.db#data/1",
        raw: '{"note": "uncheckpointed"}',
        value: { note: "uncheckpointed" },
      },
    ]);
    expect(await readFile(join(root, "actual.db"))).toEqual(dbBefore);
    expect(await readFile(join(root, "actual.db-wal"))).toEqual(walBefore);
    expect((await readdir(root)).sort()).toEqual([
      "actual.db",
      "actual.db-shm",
      "actual.db-wal",
      "alias.db",
    ]);
  } finally {
    database.close();
  }
});
