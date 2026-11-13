import { realpath } from "node:fs/promises";
import { extname, isAbsolute, relative, resolve, sep } from "node:path";
import { Type } from "typebox";
import { Value } from "typebox/value";
import { thimbleRecordSchema, type ThimbleJson, type ThimbleRecord } from "./thimble-json.js";
import {
  countThimbleSourceRows,
  listThimbleFiles,
  ThimbleSourceError,
  thimbleSourceKind,
} from "./thimble-sources.js";

type Range = [number, number];
type Unit = "records" | "rows" | "lines" | "pages" | "file";
type CoverageFile = {
  path: string;
  kind: string;
  unit: Unit;
  rows: number;
  lines: number;
  units: number;
  countError?: string;
  ranges: Range[];
  unlocatedRead: boolean;
  whole: boolean;
  model: Set<string>;
  computed: Set<string>;
  labels: Set<string>;
  modelLabels: Set<string>;
  computedBy: Set<string>;
  searchedBy: Set<string>;
  listedBy: Set<string>;
  computedWhole: boolean;
};

const unitOrder: Unit[] = ["records", "rows", "lines", "pages", "file"];
const shellLimitations =
  "Shell coverage supports standalone cat, head, tail, numeric sed -n, grep/rg, wc, ls and find with literal paths, optionally after cd DIR &&. Pipelines, redirects, substitutions, globs, scripts, shell control flow and unrecognized options are not inferred. Search output has no captured line identities and counts as searched, not read. Binary cat output is not a media read. Images count as viewed only when a tool result supplies image content. Pi Read does not render PDF pages. PDF page totals are estimates from page objects, including Flate object streams. Uncountable sources have unknown totals; known counts exclude them.";

function record(value: ThimbleJson | undefined): ThimbleRecord {
  return Value.Check(thimbleRecordSchema, value) ? value : {};
}

function mergeRanges(ranges: Range[]): Range[] {
  const merged: Range[] = [];
  for (const [start, end] of [...ranges].sort((a, b) => a[0] - b[0])) {
    const last = merged.at(-1);
    if (last && start <= last[1] + 1) last[1] = Math.max(last[1], end);
    else if (start <= end) merged.push([start, end]);
  }
  return merged;
}

function rangeSize(ranges: Range[]): number {
  return mergeRanges(ranges).reduce((sum, [a, b]) => sum + b - a + 1, 0);
}

function sourcePath(root: string, cwd: string, path: string): string | undefined {
  const rel = relative(root, resolve(cwd, path));
  if (rel === ".." || rel.startsWith(`..${sep}`) || isAbsolute(rel)) return undefined;
  return rel.split(sep).join("/");
}

async function canonicalSourcePath(
  root: string,
  cwd: string,
  path: string
): Promise<string | undefined> {
  try {
    const target = await realpath(resolve(cwd, path));
    const canonical = sourcePath(root, root, target);
    if (canonical === undefined) return undefined;
    // Preserve a confined source link's listed name, but accept OS aliases such
    // as /var -> /private/var when the session and dispatcher spell root differently.
    return sourcePath(root, cwd, path) ?? canonical;
  } catch (error) {
    if (
      error instanceof Error &&
      "code" in error &&
      ["ENOENT", "ENOTDIR", "ELOOP"].includes(String(error.code))
    )
      return undefined;
    throw error;
  }
}

async function coverageSource(
  root: string,
  path: string,
  signal?: AbortSignal
): Promise<CoverageFile> {
  const kind = thimbleSourceKind(path);
  const unitsByKind = new Map<string, Unit>([
    ["jsonl", "records"],
    ["transcript", "records"],
    ["json", "records"],
    ["csv", "rows"],
    ["sqlite", "rows"],
    ["markdown", "lines"],
    ["diff", "lines"],
    ["text", "lines"],
    ["pdf", "pages"],
  ]);
  const unit = unitsByKind.get(kind) ?? "file";
  let rows = 1;
  let lines = 0;
  let countError: string | undefined;
  try {
    if (unit !== "file") {
      ({ rows, lines } = await countThimbleSourceRows(root, path, signal));
    }
  } catch (error) {
    signal?.throwIfAborted();
    if (!(error instanceof ThimbleSourceError)) throw error;
    countError = error.message;
    rows = 0;
    lines = 0;
  }
  return {
    path,
    kind,
    unit,
    rows,
    lines,
    units: unit === "file" ? 1 : unit === "lines" ? lines : rows,
    countError,
    ranges: [],
    unlocatedRead: false,
    whole: false,
    model: new Set(),
    computed: new Set(),
    labels: new Set(),
    modelLabels: new Set(),
    computedBy: new Set(),
    searchedBy: new Set(),
    listedBy: new Set(),
    computedWhole: false,
  };
}

// A deliberately small shell lexer. Operators are recognized only outside quotes;
// quoted shell metacharacters are literal names, never commands or expansions.
function shellWords(command: string): string[] | undefined {
  const words: string[] = [];
  let word = "";
  let active = false;
  let quote = "";
  for (let i = 0; i < command.length; i++) {
    const ch = command[i];
    if (quote) {
      if (ch === quote) quote = "";
      else if (quote === '"' && /[$`\\]/.test(ch)) return undefined;
      else word += ch;
      active = true;
    } else if (ch === "'" || ch === '"') {
      quote = ch;
      active = true;
    } else if (/\s/.test(ch)) {
      if (ch === "\n") return undefined;
      if (active) words.push(word);
      word = "";
      active = false;
    } else if (/[|&;<>$`(){}*?\[\]~#!\\]/.test(ch)) return undefined;
    else {
      word += ch;
      active = true;
    }
  }
  if (quote) return undefined;
  if (active) words.push(word);
  return words;
}

async function applyShellCall(
  root: string,
  call: ThimbleRecord,
  files: Map<string, CoverageFile>
): Promise<boolean> {
  if (!Value.Check(Type.String(), call.command)) return false;
  let command = call.command.trim();
  let cwd = Value.Check(Type.String(), call.cwd) ? resolve(call.cwd) : root;
  // Only the exact cd-prefix form is supported; no other compound commands.
  const cd = command.match(/^cd\s+([^]*?)\s+&&\s+([^]*)$/);
  if (cd) {
    const directory = shellWords(cd[1]);
    if (directory?.length !== 1) return false;
    cwd = resolve(cwd, directory[0]);
    command = cd[2];
  }
  const words = shellWords(command);
  if (!words?.length) return false;
  const [program, ...args] = words;
  let paths: string[] = [];
  let mode: "read" | "searched" | "computed" | "listed" = "read";
  let folders = false;
  let span: (lines: number) => Range = (lines) => [1, lines];
  if (program === "cat") {
    paths = args[0] === "--" ? args.slice(1) : args;
    if (paths.some((path) => path.startsWith("-"))) return false;
  } else if (program === "head" || program === "tail") {
    let n = 10;
    paths = [...args];
    if (paths[0] === "-n") {
      if (!/^\+?\d+$/.test(paths[1] ?? "")) return false;
      const from = paths[1].startsWith("+");
      n = Number(paths[1]);
      paths = paths.slice(2);
      if (from) {
        if (program !== "tail" || n < 1) return false;
        span = (lines) => [n, lines];
      } else
        span = (lines) =>
          program === "head" ? [1, Math.min(n, lines)] : [Math.max(1, lines - n + 1), lines];
    } else {
      if (/^-\d+$/.test(paths[0] ?? "")) n = -Number(paths.shift());
      span = (lines) =>
        program === "head" ? [1, Math.min(n, lines)] : [Math.max(1, lines - n + 1), lines];
    }
    if (paths[0] === "--") paths.shift();
    if (paths.length !== 1 || paths[0].startsWith("-")) return false;
  } else if (program === "sed") {
    const match = args[1]?.match(/^(\d+)(?:,(\d+|\$))?p$/);
    if (args[0] !== "-n" || !match || args.length !== 3 || args[2].startsWith("-")) return false;
    paths = [args[2]];
    span = (lines) => [Number(match[1]), match[2] === "$" ? lines : Number(match[2] ?? match[1])];
  } else if (program === "wc") {
    if (!args.length || args.some((arg) => arg.startsWith("-") && !/^-[lwmcL]+$/.test(arg)))
      return false;
    paths = args.filter((arg) => !arg.startsWith("-"));
    mode = "computed";
  } else if (program === "grep" || program === "rg") {
    const remaining = [...args];
    let recursive = program === "rg";
    mode = "searched";
    while (remaining[0]?.startsWith("-") && remaining[0] !== "--") {
      const option = remaining.shift()!;
      if (!(program === "rg" ? /^-[nivwFxHclq]+$/ : /^-[nivwFxEHhcrRlLq]+$/).test(option))
        return false;
      if (/[clLq]/.test(option)) mode = "computed";
      if (/[rR]/.test(option)) recursive = true;
    }
    if (remaining[0] === "--") remaining.shift();
    if (!remaining.length) return false;
    remaining.shift(); // The pattern is never a filename.
    paths = remaining.length ? remaining : program === "rg" ? ["."] : [];
    if (paths.some((path) => path.startsWith("-"))) return false;
    if (!recursive) {
      for (const path of paths) {
        if (!files.has((await canonicalSourcePath(root, cwd, path)) ?? "")) return false;
      }
    }
    folders = recursive;
  } else if (program === "ls" || program === "find") {
    // find predicates can include commands. Only directory/file operands count.
    paths = args.length ? args : ["."];
    if (paths.some((path) => path.startsWith("-"))) return false;
    mode = "listed";
    folders = true;
  } else return false;
  if (!paths.length) return false;
  // Multiple cat files require separators/output knowledge absent from seen calls.
  if (mode === "read" && paths.length !== 1) return false;
  let left = Value.Check(Type.Integer({ minimum: 0 }), call.out_lines) ? call.out_lines : 0;
  for (const path of paths) {
    const rel = await canonicalSourcePath(root, cwd, path);
    if (rel === undefined) continue;
    const direct = files.get(rel);
    const targets = direct
      ? [direct]
      : folders
        ? [...files.values()].filter((file) => !rel || file.path.startsWith(`${rel}/`))
        : [];
    for (const file of targets) {
      file.listedBy.add(program);
      if (mode === "listed") continue;
      if (
        (program === "grep" || program === "rg") &&
        (file.unit === "file" || file.unit === "pages")
      )
        continue;
      if (mode === "searched" && file.unit !== "file" && file.unit !== "pages")
        file.searchedBy.add(program);
      else if (mode === "computed") {
        file.computedWhole = true;
        file.computedBy.add(program);
      } else if (mode === "read" && file.unit !== "file" && file.unit !== "pages") {
        const lines = file.countError ? Infinity : file.lines;
        const [a, end] = span(lines);
        const b = Math.min(end, lines, a + left - 1);
        if (Number.isFinite(a) && a >= 1 && a <= b) {
          file.ranges.push([a, b]);
          left -= b - a + 1;
        } else if (a === Infinity && left > 0) {
          // EOF-relative tail output proves exposure, but not source positions.
          file.unlocatedRead = true;
        }
      }
    }
  }
  return true;
}

function fileReport(file: CoverageFile): ThimbleRecord {
  const ranges = mergeRanges(file.ranges);
  const seenLines = rangeSize(ranges);
  const seenUnits = file.countError
    ? 0
    : file.unit === "file" || file.unit === "pages"
      ? file.whole
        ? file.units
        : 0
      : file.unit === "lines"
        ? seenLines
        : file.kind === "csv" && file.lines === file.rows + 1
          ? rangeSize(ranges.filter(([, b]) => b >= 2).map(([a, b]) => [Math.max(2, a), b]))
          : Math.min(file.units, Math.round((seenLines / Math.max(1, file.lines)) * file.units));
  const read = seenLines > 0 || seenUnits > 0 || file.unlocatedRead;
  const model = Math.min(file.rows, file.model.size);
  const computed = file.computedWhole ? file.rows : Math.min(file.rows, file.computed.size);
  const modelRead = Math.min(file.units, Math.round((model * file.units) / Math.max(1, file.rows)));
  const computedOver = Math.min(
    file.units,
    Math.round((computed * file.units) / Math.max(1, file.rows))
  );
  // Category parts never overlap. Raw model/computed counts remain available.
  const modelUnits = Math.max(0, modelRead - seenUnits);
  const searchedUnits = file.searchedBy.size ? Math.max(0, file.units - seenUnits - modelUnits) : 0;
  const computedUnits = Math.max(0, computedOver - seenUnits - modelUnits - searchedUnits);
  const touched =
    read || model > 0 || computed > 0 || file.computedWhole || file.searchedBy.size > 0;
  const status = read
    ? "seen"
    : model
      ? "model"
      : file.searchedBy.size
        ? "searched"
        : computed || file.computedWhole
          ? "computed"
          : file.listedBy.size
            ? "listed"
            : "untouched";
  const folder = file.path.includes("/")
    ? file.path.slice(0, file.path.lastIndexOf("/") + 1)
    : "./";
  const share = seenUnits / Math.max(1, file.units);
  const rowScale = file.rows / Math.max(1, file.units);
  const said = [
    read
      ? file.countError
        ? seenLines
          ? `read ${seenLines} lines`
          : "read; line positions unknown"
        : `read ${seenUnits} of ${file.units} ${file.unit}`
      : "",
    model ? `a label's model read ${model} of ${file.rows} records` : "",
    file.searchedBy.size ? "searched; which lines it showed is not known" : "",
    computed ? `computed over ${computed} of ${file.rows} records` : "",
    !read && touched ? "Pi read none of it" : "",
    !touched ? (status === "listed" ? "only listed by name; Pi read none of it" : "untouched") : "",
  ]
    .filter(Boolean)
    .join("; ");
  return {
    path: file.path,
    kind: file.kind,
    unit: file.unit,
    units: file.countError ? null : file.units,
    rows: file.countError ? null : file.rows,
    lines: file.countError ? null : file.lines,
    count_error: file.countError ?? null,
    seen_units: seenUnits,
    model_units: modelUnits,
    searched_units: searchedUnits,
    computed_units: computedUnits,
    model_read_units: modelRead,
    computed_over_units: computedOver,
    status: file.countError ? "uncountable" : status,
    seen: read,
    read,
    touched,
    share: file.countError ? null : share,
    read_share: file.countError ? null : share,
    counted_share: file.countError
      ? null
      : Math.min(
          1,
          (seenUnits + modelUnits + searchedUnits + computedUnits) / Math.max(1, file.units)
        ),
    seen_lines: seenLines,
    read_lines: seenLines,
    seen_rows: Math.round(share * file.rows),
    model,
    model_rows: Math.round(modelUnits * rowScale),
    computed,
    computed_rows: Math.round(computedUnits * rowScale),
    labels: [...file.labels].sort(),
    model_labels: [...file.modelLabels].sort(),
    searched: file.searchedBy.size > 0,
    searched_by: [...file.searchedBy].sort(),
    computed_by: [...file.computedBy].sort(),
    ranges: ranges.slice(0, 300),
    hit_lines: [],
    hits: 0,
    pages: file.unit === "pages" && file.whole ? [[1, file.rows]] : [],
    type: extname(file.path).slice(1).toLowerCase() || "no extension",
    folder,
    said: file.countError
      ? `${said}; uncountable: ${file.countError}; total ${file.unit} unknown`
      : said,
  };
}

function sum(rows: ThimbleRecord[], key: string): number {
  return rows.reduce((total, row) => total + Number(row[key] ?? 0), 0);
}

function unitReports(rows: ThimbleRecord[]): ThimbleRecord[] {
  return unitOrder.flatMap((unit) => {
    const members = rows.filter((row) => row.unit === unit);
    const uncountable = members.filter((row) => row.count_error).length;
    return members.length
      ? [
          {
            unit,
            units: uncountable ? null : sum(members, "units"),
            known_units: sum(members, "units"),
            uncountable_files: uncountable,
            seen: sum(members, "seen_units"),
            model: sum(members, "model_units"),
            searched: sum(members, "searched_units"),
            computed: sum(members, "computed_units"),
            files: members.length,
            seen_files: members.filter((row) => row.seen).length,
          },
        ]
      : [];
  });
}

function groupReports(rows: ThimbleRecord[], key: "folder" | "type"): ThimbleRecord[] {
  const groups = new Map<string, ThimbleRecord[]>();
  for (const row of rows) {
    const name = String(row[key]);
    const members = groups.get(name) ?? [];
    members.push(row);
    groups.set(name, members);
  }
  return [...groups].map(([name, members]) => {
    const units = unitReports(members);
    const uncountable = members.filter((row) => row.count_error).length;
    const byStatus: ThimbleRecord = {};
    for (const row of members)
      byStatus[String(row.status)] = Number(byStatus[String(row.status)] ?? 0) + 1;
    const size = sum(units, "units");
    return {
      [key]: name,
      group: name,
      files: members.length,
      rows: uncountable ? null : sum(members, "rows"),
      known_rows: sum(members, "rows"),
      uncountable_files: uncountable,
      seen_rows: sum(members, "seen_rows"),
      read_rows: sum(members, "seen_rows"),
      model_rows: sum(members, "model_rows"),
      computed_rows: sum(members, "computed_rows"),
      computed: sum(members, "computed"),
      touched: members.filter((row) => row.touched).length,
      seen_files: members.filter((row) => row.seen).length,
      by_status: byStatus,
      units,
      read_share: uncountable
        ? null
        : units.length === 1 && size
          ? sum(units, "seen") / size
          : sum(members, "read_share") / members.length,
      counted_share: uncountable
        ? null
        : units.length === 1 && size
          ? (sum(units, "seen") +
              sum(units, "model") +
              sum(units, "searched") +
              sum(units, "computed")) /
            size
          : sum(members, "counted_share") / members.length,
    };
  });
}

/** Report this session's file coverage without running shell commands or opening outward symlink targets. */
export async function thimbleCoverageReport(
  root: string,
  seen: readonly ThimbleJson[],
  labels: readonly ThimbleRecord[],
  signal?: AbortSignal
): Promise<ThimbleRecord> {
  signal?.throwIfAborted();
  root = await realpath(root);
  const files = new Map<string, CoverageFile>();
  for (const path of await listThimbleFiles(root, signal)) {
    signal?.throwIfAborted();
    files.set(path, await coverageSource(root, path, signal));
  }
  for (const label of labels) {
    const labelFiles = (Array.isArray(label.files) ? label.files : [...files.keys()])
      .filter((file): file is string => Value.Check(Type.String(), file))
      .sort((a, b) => b.length - a.length);
    for (const [ref, value] of Object.entries(record(label.units))) {
      const unit = record(value);
      const name = labelFiles.find((file) => ref.startsWith(`${file}#`));
      const path = name === undefined ? undefined : sourcePath(root, root, name);
      const file = path === undefined ? undefined : files.get(path);
      if (!file || !["model", "regex", "code"].includes(String(unit.by))) continue;
      file.labels.add(String(label.name));
      if (unit.by === "model") {
        file.model.add(ref);
        file.modelLabels.add(String(label.name));
      } else file.computed.add(ref);
    }
  }
  let unsupportedShellCalls = 0;
  for (const value of seen) {
    signal?.throwIfAborted();
    const call = record(value);
    if (call.tool === "Bash") {
      if (!(await applyShellCall(root, call, files))) unsupportedShellCalls++;
      continue;
    }
    if (call.tool !== "Read" || !Value.Check(Type.String(), call.file)) continue;
    const path = await canonicalSourcePath(
      root,
      Value.Check(Type.String(), call.cwd) ? call.cwd : root,
      call.file
    );
    const file = path === undefined ? undefined : files.get(path);
    if (!file) continue;
    file.listedBy.add("Read");
    if (file.unit === "file" && call.image === true) file.whole = true;
    else if (
      file.unit !== "file" &&
      file.unit !== "pages" &&
      Value.Check(Type.Integer({ minimum: 1 }), call.from) &&
      Value.Check(Type.Integer({ minimum: 1 }), call.to)
    ) {
      const a = Math.max(1, call.from);
      const b = file.countError ? call.to : Math.min(file.lines, call.to);
      if (a <= b) file.ranges.push([a, b]);
    }
  }
  const all = [...files.values()].map(fileReport);
  const touched = all.filter((file) => file.touched);
  const quiet = all.filter((file) => !file.touched);
  const read = all.filter((file) => file.seen);
  const unread = all.filter((file) => !file.seen);
  const uncountable = all.filter((file) => file.count_error);
  const rows = sum(all, "rows");
  const total: ThimbleRecord = {
    files: all.length,
    rows: uncountable.length ? null : rows,
    known_rows: rows,
    uncountable_files: uncountable.length,
    touched_files: touched.length,
    touched_share: touched.length / (all.length || 1),
    seen_files: read.length,
    seen_rows: sum(all, "seen_rows"),
    seen_share: read.length / (all.length || 1),
    model_files: all.filter((file) => Number(file.model) > 0).length,
    model_rows: sum(all, "model_rows"),
    model_share: uncountable.length ? null : sum(all, "model_rows") / (rows || 1),
    computed_files: all.filter((file) => Number(file.computed_rows) > 0).length,
    computed_rows: sum(all, "computed_rows"),
    computed_share: uncountable.length ? null : sum(all, "computed_rows") / (rows || 1),
    not_seen_files: unread.length,
    not_seen_rows: uncountable.length ? null : sum(unread, "rows"),
    known_not_seen_rows: sum(unread, "rows"),
    listed_files: quiet.filter((file) => file.status === "listed").length,
    untouched_files: quiet.filter((file) => file.status === "untouched").length,
    units: unitReports(all),
    not_seen_units: unitReports(unread),
    read_files: read.length,
    read_rows: sum(all, "seen_rows"),
    read_share: read.length / (all.length || 1),
    not_read_files: unread.length,
    not_read_rows: uncountable.length ? null : sum(unread, "rows"),
    known_not_read_rows: sum(unread, "rows"),
  };
  const samples: CoverageFile[] = [];
  const folderSamples = new Map<string, number>();
  for (const row of quiet) {
    const folder = String(row.folder);
    const n = folderSamples.get(folder) ?? 0;
    if (n < 200) samples.push(files.get(String(row.path))!);
    folderSamples.set(folder, n + 1);
  }
  const amounts = (key: string) =>
    unitReports(all)
      .map((unit) =>
        unit.uncountable_files
          ? `${unit[key]} of ${unit.known_units} known ${unit.unit} (${unit.uncountable_files} uncountable files)`
          : `${unit[key]} of ${unit.units} ${unit.unit}`
      )
      .join(", ");
  const summary = all.length
    ? [
        `Coverage of this session · ${all.length} files`,
        ...(uncountable.length
          ? [
              `Count errors: ${uncountable.length} uncountable files; totals are unknown and known counts exclude these files.`,
              ...uncountable.map((file) => `  ${file.path}  ${file.said}`),
            ]
          : []),
        ...touched.slice(0, 15).map((file) => `  ${file.path}  ${file.said}`),
        ...(touched.length > 15 ? [`  ... and ${touched.length - 15} more touched files`] : []),
        `Touched ${touched.length} of ${all.length} files (read, searched or computed over).`,
        `Read ${read.length} of the files, at least in part: ${amounts("seen")}. Not read: ${unread.length} files.`,
        `Read by a label's model: ${amounts("model")}. Computed over, none of it read: ${amounts("computed")}.`,
        `Only listed: ${total.listed_files}. Untouched: ${total.untouched_files}.`,
      ].join("\n")
    : "There are no files.";
  return {
    root,
    files: all.filter((file) => file.touched || file.count_error),
    total,
    groups: groupReports(all, "folder").sort(
      (a, b) =>
        Number(b.touched) - Number(a.touched) ||
        Number(b.files) - Number(a.files) ||
        String(a.folder).localeCompare(String(b.folder))
    ),
    types: groupReports(all, "type").sort(
      (a, b) => Number(b.rows) - Number(a.rows) || String(a.type).localeCompare(String(b.type))
    ),
    untouched: {
      path: samples.map((file) => file.path),
      unit: samples.map((file) => file.unit),
      units: samples.map((file) => (file.countError ? null : file.units)),
      by: samples.map((file) => [...file.listedBy].sort().slice(0, 4).join(", ")),
    },
    limitations: shellLimitations,
    unsupported_shell_calls: unsupportedShellCalls,
    summary: `${summary}\n${shellLimitations}${unsupportedShellCalls ? ` Unsupported Bash calls: ${unsupportedShellCalls}.` : ""}`,
  };
}
