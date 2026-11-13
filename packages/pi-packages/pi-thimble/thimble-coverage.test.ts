import { afterEach, beforeEach, expect, test } from "bun:test";
import { mkdir, mkdtemp, realpath, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { deflateSync } from "node:zlib";
import { Type } from "typebox";
import { Value } from "typebox/value";
import { thimbleCoverageReport } from "./thimble-coverage.js";
import { thimbleRecordSchema, type ThimbleRecord } from "./thimble-json.js";

let root: string;
beforeEach(async () => {
  root = await mkdtemp(join(tmpdir(), "thimble-coverage-"));
});
afterEach(async () => {
  await rm(root, { recursive: true, force: true });
});

function read(file: string, from: number | null, to: number | null): ThimbleRecord {
  return { tool: "Read", cwd: root, file: join(root, file), from, to };
}

function bash(command: string, out_lines = 100): ThimbleRecord {
  return { tool: "Bash", cwd: root, command, out_lines };
}

function files(report: ThimbleRecord): ThimbleRecord[] {
  if (!Value.Check(Type.Array(thimbleRecordSchema), report.files))
    throw new Error("Coverage report has no file records");
  return report.files;
}

test("overlapping reads merge, clip at EOF and do not turn named files into reads", async () => {
  await writeFile(join(root, "record.txt"), "one\ntwo\nthree\nfour\nfive\nsix\n");
  await writeFile(join(root, "quiet.txt"), "unread\n");
  const report = await thimbleCoverageReport(
    root,
    [
      read("record.txt", 2, 4),
      read("record.txt", 3, 5),
      read("record.txt", 5, 90),
      read("quiet.txt", null, null),
    ],
    []
  );
  expect(report).toMatchObject({
    files: [{ path: "record.txt", ranges: [[2, 6]], seen_units: 5, units: 6, seen_lines: 5 }],
    total: {
      files: 2,
      seen_files: 1,
      touched_files: 1,
      listed_files: 1,
      untouched_files: 0,
      not_seen_files: 1,
    },
    untouched: { path: ["quiet.txt"], by: ["Read"] },
  });
  expect(files(report)[0].read_share).toBeCloseTo(5 / 6);
});

test("CSV header is visible text but not a data row", async () => {
  await writeFile(join(root, "table.csv"), "name,result\na,yes\nb,no\nc,yes\n");
  const header = await thimbleCoverageReport(root, [read("table.csv", 1, 1)], []);
  expect(files(header)[0]).toMatchObject({
    unit: "rows",
    units: 3,
    lines: 4,
    seen_lines: 1,
    seen_units: 0,
    seen: true,
  });
  const body = await thimbleCoverageReport(
    root,
    [read("table.csv", 1, 2), read("table.csv", 2, 3)],
    []
  );
  expect(files(body)[0]).toMatchObject({ ranges: [[1, 3]], seen_units: 2, units: 3 });
});

test("canonical root accepts Pi reads and Bash cwd using another spelling of the temp root", async () => {
  await writeFile(join(root, "record.txt"), "one\ntwo\nthree\nfour\nfive\nsix\n");
  const canonical = await realpath(root);
  const report = await thimbleCoverageReport(canonical, [read("record.txt", 3, 4)], []);
  expect(report).toMatchObject({
    files: [{ path: "record.txt", ranges: [[3, 4]], seen_units: 2, units: 6 }],
  });
  const aliasDirectory = await mkdtemp(join(tmpdir(), "thimble-root-alias-"));
  try {
    const alias = join(aliasDirectory, "workspace");
    await symlink(root, alias);
    const calls: ThimbleRecord[] = [
      { tool: "Read", cwd: alias, file: join(alias, "record.txt"), from: 2, to: 3 },
      { tool: "Bash", cwd: alias, command: "tail -n 1 record.txt", out_lines: 1 },
    ];
    const aliased = await thimbleCoverageReport(canonical, calls, []);
    expect(files(aliased)[0]).toMatchObject({
      path: "record.txt",
      ranges: [
        [2, 3],
        [6, 6],
      ],
      seen_units: 3,
      units: 6,
    });
  } finally {
    await rm(aliasDirectory, { recursive: true, force: true });
  }
});

test("label files disambiguate hashes in filenames before the record selector", async () => {
  await writeFile(join(root, "run.jsonl"), '{"v":0}\n');
  await writeFile(join(root, "run.jsonl#part.jsonl"), '{"v":1}\n{"v":2}\n');
  const report = await thimbleCoverageReport(
    root,
    [],
    [
      {
        name: "hash-file",
        files: ["run.jsonl", "run.jsonl#part.jsonl"],
        units: {
          "run.jsonl#part.jsonl#L1": { by: "model", v: true },
          "run.jsonl#part.jsonl#L2": { by: "regex", v: false },
        },
      },
    ]
  );
  expect(report).toMatchObject({
    files: [{ path: "run.jsonl#part.jsonl", units: 2, model: 1, computed: 1, status: "model" }],
    total: { files: 2, touched_files: 1, untouched_files: 1 },
  });
});

test("model labels, rule labels and seen units have separate non-overlapping counts", async () => {
  await writeFile(join(root, "runs.jsonl"), '{"v":1}\n{"v":2}\n{"v":3}\n{"v":4}\n');
  const labels: ThimbleRecord[] = [
    {
      name: "model",
      units: {
        "runs.jsonl#L1": { by: "model", v: true },
        "runs.jsonl#L2": { by: "model", v: false },
      },
    },
    {
      name: "rule",
      units: {
        "runs.jsonl#L1": { by: "regex", v: true },
        "runs.jsonl#L2": { by: "regex", v: false },
        "runs.jsonl#L3": { by: "code", v: true },
        "runs.jsonl#L4": { by: "code", v: false },
      },
    },
  ];
  const report = await thimbleCoverageReport(root, [read("runs.jsonl", 1, 1)], labels);
  expect(files(report)[0]).toMatchObject({
    status: "seen",
    seen_units: 1,
    model: 2,
    model_units: 1,
    model_read_units: 2,
    computed: 4,
    computed_units: 2,
    computed_over_units: 4,
    model_labels: ["model"],
    labels: ["model", "rule"],
    counted_share: 1,
  });
  const ruleOnly = await thimbleCoverageReport(root, [], [labels[1]]);
  expect(files(ruleOnly)[0]).toMatchObject({
    status: "computed",
    seen: false,
    model: 0,
    computed_units: 4,
  });
  expect(ruleOnly.summary).toContain("Pi read none of it");
});

test("literal Bash readers preserve ranges and output budgets", async () => {
  await mkdir(join(root, "sub"));
  await writeFile(join(root, "sub", "a b.txt"), "1\n2\n3\n4\n5\n6\n");
  const calls = [
    bash("cd sub && head -n 2 'a b.txt'", 1),
    bash("tail -n 2 'sub/a b.txt'", 2),
    bash("sed -n '3,4p' 'sub/a b.txt'", 1),
  ];
  const report = await thimbleCoverageReport(root, calls, []);
  expect(files(report)[0]).toMatchObject({
    ranges: [
      [1, 1],
      [3, 3],
      [5, 6],
    ],
    seen_units: 4,
  });
  expect(report.unsupported_shell_calls).toBe(0);
  const cat = await thimbleCoverageReport(root, [bash("cat -- 'sub/a b.txt'", 2)], []);
  expect(files(cat)[0]).toMatchObject({ ranges: [[1, 2]], seen_units: 2 });
});

test("search patterns are not filenames and counts never claim a read", async () => {
  await writeFile(join(root, "pattern.txt"), "not searched\n");
  await writeFile(join(root, "data.txt"), "pattern.txt\nother\n");
  const report = await thimbleCoverageReport(root, [bash("grep -n pattern.txt data.txt", 1)], []);
  expect(report).toMatchObject({
    files: [{ path: "data.txt", status: "searched", seen_units: 0, searched_units: 2 }],
    total: { seen_files: 0, untouched_files: 1 },
  });
  const counted = await thimbleCoverageReport(root, [bash("wc -l data.txt", 1)], []);
  expect(files(counted)[0]).toMatchObject({ status: "computed", computed_units: 2, seen: false });
});

test("ambiguous shell syntax and quoted command text cannot masquerade as file reads", async () => {
  await writeFile(join(root, "data.txt"), "private\ncontent\n");
  const commands = [
    "echo cat data.txt",
    "printf 'cat data.txt'",
    "cat data.txt | head -n 1",
    "cat data.txt > output.txt",
    "python -c 'print(open(\"data.txt\").read())'",
    "cat $(echo data.txt)",
    "false && cat data.txt",
    "cat *.txt",
    "head -c 2 data.txt",
    "grep --help data.txt",
    "find . -exec cat data.txt \\;",
  ];
  const report = await thimbleCoverageReport(
    root,
    commands.map((command) => bash(command)),
    []
  );
  expect(report).toMatchObject({
    files: [],
    total: { seen_files: 0, touched_files: 0, untouched_files: 1 },
    unsupported_shell_calls: commands.length,
  });
  expect(report.limitations).toContain("Pipelines");
});

test("listing a folder is not touching it and quiet accounting includes each file", async () => {
  await mkdir(join(root, "sub"));
  await writeFile(join(root, "a.txt"), "1\n2\n");
  await writeFile(join(root, "sub", "b.txt"), "3\n");
  const report = await thimbleCoverageReport(root, [bash("ls sub")], []);
  expect(report).toMatchObject({
    files: [],
    total: { files: 2, listed_files: 1, untouched_files: 1, touched_files: 0, rows: 3 },
    untouched: { path: ["a.txt", "sub/b.txt"], units: [2, 1], by: ["", "ls"] },
  });
});

test("PDF estimates remain separate from image exposure and text or empty media reads", async () => {
  const packed = deflateSync(Buffer.from("3 0 4 20 /Type /Page /Type /Page"));
  await writeFile(
    join(root, "doc.pdf"),
    Buffer.concat([
      Buffer.from(
        "%PDF-1.5\n/Type /Pages /Count 3\n/Type /Page\n/Type /ObjStm /Filter /FlateDecode\nstream\n"
      ),
      packed,
      Buffer.from("\nendstream\n%%EOF"),
    ])
  );
  await writeFile(join(root, "photo.png"), Buffer.from([137, 80, 78, 71, 0]));
  await writeFile(join(root, "sound.wav"), Buffer.from([82, 73, 70, 70, 0]));
  const report = await thimbleCoverageReport(
    root,
    [
      read("doc.pdf", null, null),
      read("doc.pdf", 1, 3),
      read("photo.png", null, null),
      read("sound.wav", 1, 1),
      bash("cat sound.wav"),
    ],
    []
  );
  expect(report).toMatchObject({
    files: [],
    total: { files: 3, seen_files: 0, listed_files: 3 },
    untouched: { path: ["doc.pdf", "photo.png", "sound.wav"], units: [3, 1, 1] },
  });
  const exposed = await thimbleCoverageReport(
    root,
    [{ ...read("photo.png", null, null), image: true }],
    []
  );
  expect(exposed).toMatchObject({
    files: [{ path: "photo.png", unit: "file", units: 1, seen_units: 1 }],
    total: { files: 3, seen_files: 1, untouched_files: 2 },
  });
});

test("malformed sources remain visible and unknown totals do not erase valid counts", async () => {
  await mkdir(join(root, "nested"));
  await writeFile(join(root, "broken.json"), "{broken");
  await writeFile(join(root, "nested", "broken.sqlite"), "not a database");
  await writeFile(join(root, "valid.jsonl"), '{"v":1}\n{"v":2}\n');
  await writeFile(join(root, "empty.json"), "[]");
  const report = await thimbleCoverageReport(root, [read("valid.jsonl", 1, 1)], []);
  expect(report).toMatchObject({
    total: { files: 4, rows: null, known_rows: 2, uncountable_files: 2, seen_rows: 1 },
    files: [
      {
        path: "broken.json",
        status: "uncountable",
        rows: null,
        units: null,
        count_error: expect.any(String),
      },
      {
        path: "nested/broken.sqlite",
        status: "uncountable",
        rows: null,
        units: null,
        count_error: expect.any(String),
      },
      { path: "valid.jsonl", rows: 2, seen_rows: 1 },
    ],
  });
  expect(report.summary).toContain("2 uncountable files");
  expect(report.summary).toContain("nested/broken.sqlite");
  expect(report.summary).toContain("known records");
  expect(report).toMatchObject({
    types: expect.arrayContaining([
      expect.objectContaining({ type: "json", rows: null, known_rows: 0, uncountable_files: 1 }),
    ]),
    total: {
      units: expect.arrayContaining([
        expect.objectContaining({
          unit: "records",
          units: null,
          known_units: 2,
          uncountable_files: 1,
          seen: 1,
        }),
        expect.objectContaining({
          unit: "rows",
          units: null,
          known_units: 0,
          uncountable_files: 1,
        }),
      ]),
    },
  });
});

test("uncountable sources retain confirmed reads without inventing record totals or tail positions", async () => {
  await writeFile(join(root, "broken.json"), "{broken\ntwo\nthree\nfour\nfive\nsix\n");
  await writeFile(join(root, "valid.jsonl"), '{"v":1}\n{"v":2}\n');
  const cases = [
    {
      calls: [read("broken.json", 2, 4), read("broken.json", 3, 5)],
      ranges: [[2, 5]],
      lines: 4,
      seen: true,
    },
    { calls: [bash("cat broken.json", 3)], ranges: [[1, 3]], lines: 3, seen: true },
    { calls: [bash("head -n 4 broken.json", 2)], ranges: [[1, 2]], lines: 2, seen: true },
    { calls: [bash("sed -n '3,5p' broken.json", 2)], ranges: [[3, 4]], lines: 2, seen: true },
    { calls: [bash("tail -n +3 broken.json", 2)], ranges: [[3, 4]], lines: 2, seen: true },
    { calls: [bash("tail -n 2 broken.json", 2)], ranges: [], lines: 0, seen: true },
    { calls: [bash("tail -n 2 broken.json", 0)], ranges: [], lines: 0, seen: false },
  ];
  for (const scenario of cases) {
    const report = await thimbleCoverageReport(
      root,
      [read("valid.jsonl", 1, 1), ...scenario.calls],
      []
    );
    expect(files(report).find((file) => file.path === "broken.json")).toMatchObject({
      status: "uncountable",
      rows: null,
      lines: null,
      units: null,
      share: null,
      read_share: null,
      counted_share: null,
      seen: scenario.seen,
      touched: scenario.seen,
      ranges: scenario.ranges,
      seen_lines: scenario.lines,
      seen_units: 0,
      seen_rows: 0,
      count_error: expect.any(String),
    });
    const seenFiles = scenario.seen ? 2 : 1;
    expect(report).toMatchObject({
      total: {
        files: 2,
        rows: null,
        known_rows: 2,
        uncountable_files: 1,
        seen_files: seenFiles,
        touched_files: seenFiles,
        not_seen_files: scenario.seen ? 0 : 1,
        seen_rows: 1,
        units: [{ unit: "records", units: null, known_units: 2, seen: 1 }],
      },
      groups: [{ rows: null, known_rows: 2, seen_files: seenFiles, seen_rows: 1 }],
    });
    expect(report.summary).toContain(`Read ${seenFiles} of the files`);
    if (scenario.seen) {
      expect(report.summary).toContain(
        scenario.lines ? `read ${scenario.lines} lines` : "read; line positions unknown"
      );
    }
  }
});

test("coverage never follows outward file or directory links", async () => {
  const outside = await mkdtemp(join(tmpdir(), "thimble-outside-"));
  try {
    await writeFile(join(outside, "secret.txt"), "must not count\n");
    await writeFile(join(root, "local.txt"), "local\n");
    await symlink(join(outside, "secret.txt"), join(root, "escape.txt"));
    await symlink(outside, join(root, "escape-dir"));
    const report = await thimbleCoverageReport(
      root,
      [read("escape.txt", 1, 10), read("escape-dir/secret.txt", 1, 10)],
      []
    );
    expect(report).toMatchObject({
      total: { files: 1, seen_files: 0, rows: 1 },
      untouched: { path: ["local.txt"] },
    });
  } finally {
    await rm(outside, { recursive: true, force: true });
  }
});

test("coverage propagates SQLite WAL confinement failures instead of reporting count errors", async () => {
  const outside = await mkdtemp(join(tmpdir(), "thimble-wal-outside-"));
  try {
    await writeFile(join(root, "events.sqlite"), "not a database");
    await writeFile(join(outside, "private-wal"), "must not open");
    await symlink(join(outside, "private-wal"), join(root, "events.sqlite-wal"));
    await expect(thimbleCoverageReport(root, [], [])).rejects.toThrow("outside the working folder");
  } finally {
    await rm(outside, { recursive: true, force: true });
  }
});

test("coverage propagates cancellation before touching sources", async () => {
  const controller = new AbortController();
  controller.abort(new Error("coverage cancelled"));
  await expect(thimbleCoverageReport(root, [], [], controller.signal)).rejects.toThrow(
    "coverage cancelled"
  );
});
