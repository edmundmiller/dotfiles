// TypeScript adaptation of safety-research/thimble's Apache-2.0 label engine.
import { randomUUID } from "node:crypto";
import { mkdir, readFile, readdir, rename, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { setTimeout as delay } from "node:timers/promises";
import { Type, type Static } from "typebox";
import { Value } from "typebox/value";
import {
  parseThimbleJson,
  thimbleJsonSchema,
  thimbleRecordSchema,
  type ThimbleJson,
  type ThimbleRecord,
} from "./thimble-json.js";
import { matchThimbleRegex } from "./thimble-regex.js";
import {
  expandThimbleGlob,
  readThimbleRows,
  readThimbleSource,
  sampleThimbleRows,
  thimbleSourceKind,
  type ThimbleSourceRow,
} from "./thimble-sources.js";

const labelSchema = Type.Object({
  name: Type.String(),
  version: Type.Number(),
  kind: Type.String(),
  rule: Type.Union([Type.String(), Type.Null()]),
  in: Type.Union([Type.String(), Type.Null()]),
  values: Type.Array(Type.String()),
  units: Type.Record(
    Type.String(),
    Type.Object({
      v: Type.Union([Type.String(), Type.Null()]),
      c: Type.Optional(Type.Union([Type.Number(), Type.Null()])),
      by: Type.Optional(Type.String()),
      wait: Type.Optional(Type.Boolean()),
      out: Type.Optional(Type.Boolean()),
      err: Type.Optional(Type.String()),
      why: Type.Optional(Type.String()),
    })
  ),
  checks: Type.Record(
    Type.String(),
    Type.Object({
      v: Type.String(),
      was: Type.Union([Type.String(), Type.Null()]),
      at: Type.Number(),
    })
  ),
  created: Type.Number(),
  rev: Type.Number(),
  sessions: Type.Optional(Type.Array(Type.String())),
  files: Type.Optional(Type.Array(Type.String())),
  matched: Type.Optional(Type.Number()),
  trial: Type.Optional(Type.Boolean()),
  limit: Type.Optional(Type.Union([Type.Number(), Type.Null()])),
  seed: Type.Optional(Type.Number()),
  run: Type.Optional(Type.Record(Type.String(), thimbleJsonSchema)),
  versions: Type.Optional(Type.Array(Type.Record(Type.String(), thimbleJsonSchema))),
});
type ThimbleLabel = Static<typeof labelSchema>;

function safeName(name: string) {
  return name.replace(/[^A-Za-z0-9_-]/g, "-").slice(0, 80) || "none";
}

function labelSlug(name: string) {
  return (
    name
      .trim()
      .replace(/[^A-Za-z0-9_-]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .toLowerCase() || "label"
  );
}

/** Keep the upstream folder hash so existing Pi label stores remain readable. */
export function thimbleLabelDirectory(root: string, home: string, session: string): string {
  let h1 = 0x811c9dc5,
    h2 = 0x9747b28c;
  for (const ch of root) {
    const code = ch.codePointAt(0)!;
    h1 = Math.imul(h1 ^ code, 0x01000193) >>> 0;
    h2 = Math.imul(h2 ^ code, 0x5bd1e995) >>> 0;
  }
  const hash = (h1.toString(16).padStart(8, "0") + h2.toString(16).padStart(8, "0")).slice(0, 12);
  const tail =
    root
      .replace(/[^A-Za-z0-9_-]/gu, "-")
      .slice(-40)
      .replace(/^-+/, "") || "root";
  return join(home, "conversations", safeName(session), "folders", `${tail}-${hash}`, "labels");
}

async function loadLabel(directory: string, name: string): Promise<ThimbleLabel | undefined> {
  let text: string;
  try {
    text = await readFile(join(directory, `${labelSlug(name)}.json`), "utf8");
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") return undefined;
    throw error;
  }
  return Value.Parse(labelSchema, parseThimbleJson(text));
}

/** Read only this session's labels; atomic replacement prevents partial JSON reads. */
export async function loadThimbleLabels(directory: string): Promise<ThimbleLabel[]> {
  let names: string[];
  try {
    names = await readdir(directory);
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") return [];
    throw error;
  }
  const labels: ThimbleLabel[] = [];
  for (const file of names.sort().filter((file) => file.endsWith(".json"))) {
    const label = await loadLabel(directory, file.slice(0, -5));
    if (label) labels.push(label);
  }
  return labels;
}

function labelStatus(label: ThimbleLabel) {
  const units = Object.entries(label.units).filter(([, unit]) => !unit.out);
  const counts: Record<string, number> = Object.create(null);
  for (const [ref, unit] of units) {
    const value = label.checks[ref]?.v ?? unit.v;
    if (value !== null) counts[value] = (counts[value] ?? 0) + 1;
  }
  const checks = Object.values(label.checks);
  return {
    records: units.length,
    valued: Object.values(counts).reduce((a, b) => a + b, 0),
    waiting: units.filter(([, unit]) => unit.wait).length,
    failed: units.filter(([ref, unit]) => unit.v === null && !unit.wait && !label.checks[ref])
      .length,
    out: Object.keys(label.units).length - units.length,
    checked: checks.length,
    agree: checks.filter((check) => check.was !== null && check.was === check.v).length,
    disagree: checks.filter((check) => check.was !== null && check.was !== check.v).length,
    counts,
    run: label.run ?? {},
  };
}

function labelHead(label: ThimbleLabel) {
  return {
    name: label.name,
    kind: label.kind,
    rule: label.rule ?? "",
    values: label.values,
    in: label.in,
    trial: Boolean(label.trial),
    limit: label.limit ?? null,
    seed: label.seed ?? 0,
    made: label.created,
    by: "pi",
    matched: label.matched ?? null,
    version: label.version,
    rev: label.rev,
    ...labelStatus(label),
  };
}

function fileForRef(label: ThimbleLabel, ref: string) {
  // Literal # in filenames is not a record delimiter. Prefer known source names.
  const file = [...(label.files ?? [])]
    .sort((a, b) => b.length - a.length)
    .find((file) => ref.startsWith(`${file}#`));
  return file ?? ref.slice(0, ref.lastIndexOf("#"));
}

async function labelRows(root: string, label: ThimbleLabel, refs: string[], signal?: AbortSignal) {
  const rows = new Map<string, ThimbleSourceRow>();
  for (const file of new Set(refs.map((ref) => fileForRef(label, ref)))) {
    signal?.throwIfAborted();
    // readThimbleRows revalidates every open, including saved sources replaced by links.
    try {
      const selector = label.in?.split("#").slice(1).join("#") || undefined;
      for (const row of await readThimbleRows(root, file, selector, signal, refs))
        rows.set(row.ref, row);
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) throw error;
    }
  }
  return rows;
}

function decodedRegexText(value: ThimbleJson): string {
  if (Value.Check(Type.String(), value)) return value;
  if (value === null) return "";
  if (Array.isArray(value)) return value.map(decodedRegexText).join("\n");
  if (Value.Check(thimbleRecordSchema, value))
    return Object.values(value).map(decodedRegexText).join("\n");
  return Value.Check(Type.Boolean(), value) ? (value ? "True" : "False") : String(value);
}

function regexRowText(row: ThimbleSourceRow, file: string) {
  return ["json", "jsonl"].includes(thimbleSourceKind(file)) &&
    !Value.Check(Type.String(), row.value)
    ? decodedRegexText(row.value)
    : row.raw;
}

function recordText(row: ThimbleSourceRow, cut: number, rule = "") {
  if (row.raw.length <= cut || !Value.Check(thimbleRecordSchema, row.value)) {
    const text = Value.Check(Type.String(), row.value) ? row.value : row.raw;
    return text.length <= cut ? text : `${text.slice(0, cut)} … (+${text.length - cut} characters)`;
  }
  // Cut long fields separately so a late field the definition names is retained.
  const entries = Object.entries(row.value).map(([key, value]) => [
    key,
    Value.Check(Type.String(), value) ? value : JSON.stringify(value),
  ]);
  const named = entries.filter(([key]) => rule.includes(key));
  const others = entries.filter(([key]) => !rule.includes(key));
  let remaining = cut;
  const fields: Record<string, string> = Object.create(null);
  for (const [key, value] of [...named, ...others]) {
    const room = Math.max(
      20,
      Math.floor(remaining / (entries.length - Object.keys(fields).length)) - key.length - 8
    );
    fields[key] =
      value.length <= room
        ? value
        : `${value.slice(0, room)} … (+${value.length - room} characters)`;
    remaining -= fields[key].length + key.length + 8;
  }
  return JSON.stringify(fields);
}

async function saveLabel(directory: string, label: ThimbleLabel, signal?: AbortSignal) {
  signal?.throwIfAborted();
  label.rev++;
  const now = Date.now() / 1000;
  const status = labelStatus(label);
  if (!status.waiting) {
    const rows = [
      ...label.values.map((value) => [value, [String(status.counts[value] ?? 0)]]),
      ["all", [String(status.records)]],
    ];
    const kept = label.versions ?? [];
    if (JSON.stringify(kept.at(-1)?.rows) !== JSON.stringify(rows)) {
      kept.push({
        v: Number(kept.at(-1)?.v ?? 0) + 1,
        at: now,
        def: label.version,
        made: `${label.trial ? "a trial over" : "run over"} ${status.records} records; ${status.checked} checked`,
        cols: ["records"],
        rows,
      });
    }
    label.versions = kept;
  }
  const file = join(directory, `${labelSlug(label.name)}.json`);
  const temporary = `${file}.${randomUUID()}.tmp`;
  try {
    await writeFile(temporary, JSON.stringify({ ...label, updated: now }, null, 1) + "\n", {
      flag: "wx",
      mode: 0o600,
    });
    signal?.throwIfAborted();
    await rename(temporary, file);
  } finally {
    await rm(temporary, { force: true });
  }
}

async function withLabelLock<T>(
  directory: string,
  action: () => Promise<T>,
  signal?: AbortSignal
): Promise<T> {
  await mkdir(directory, { recursive: true, mode: 0o700 });
  const lock = `${directory}.lock`;
  for (;;) {
    signal?.throwIfAborted();
    try {
      await mkdir(lock);
      break;
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "EEXIST")) throw error;
      // Never steal a lock after a time threshold: a paused writer can resume.
      // The operation deadline bounds waiting. A crash leaves its PID for diagnosis.
      await delay(25, undefined, { signal });
    }
  }
  try {
    await writeFile(join(lock, "pid"), String(process.pid));
    return await action();
  } finally {
    await rm(lock, { recursive: true, force: true });
  }
}

const labelRequestSchema = Type.Object({
  action: Type.Union([
    Type.Literal("list"),
    Type.Literal("records"),
    Type.Literal("waiting"),
    Type.Literal("check"),
    Type.Literal("regex"),
    Type.Literal("prompt"),
  ]),
  name: Type.Optional(Type.String({ minLength: 1 })),
  glob: Type.Optional(Type.String()),
  rule: Type.Optional(Type.String()),
  values: Type.Optional(Type.Array(Type.String({ minLength: 1 }), { minItems: 2, maxItems: 12 })),
  limit: Type.Optional(Type.Integer({ minimum: 1, maximum: 100 })),
  ref: Type.Optional(Type.String()),
  value: Type.Optional(Type.String()),
});

/** Execute the Pi label contract against upstream-compatible, session-scoped JSON state. */
export async function runThimbleLabel(
  root: string,
  directory: string,
  session: string,
  payload: ThimbleJson,
  signal?: AbortSignal
): Promise<ThimbleJson> {
  const request = Value.Parse(labelRequestSchema, payload);
  if (request.action === "list" && !request.name)
    return (await loadThimbleLabels(directory)).map(labelHead);
  if (!request.name) throw new Error("Thimble label requires a name for this action");
  const name = request.name;
  if (request.action === "regex" || request.action === "prompt") {
    if (!request.glob || !request.rule)
      throw new Error("Thimble label creation requires glob and rule");
    const pattern = request.glob.trim();
    const [glob, ...fragments] = pattern.split("#");
    const selector = fragments.join("#") || undefined;
    const files = await expandThimbleGlob(root, glob, signal);
    if (!files.length) throw new Error(`Thimble label: no source file matches ${glob}`);
    const values = (request.values ?? ["yes", "no"]).map((value) => value.trim()).filter(Boolean);
    if (values.length < 2 || values.some((value) => value.includes(",")))
      throw new Error("Thimble label needs at least two nonempty values without commas");
    const limit = request.limit ?? 100;
    const { rows, matched } = await sampleThimbleRows(root, files, selector, limit, signal);
    if (selector?.startsWith("/") && !matched)
      throw new Error("Thimble label pointer names no records");
    const hits =
      request.action === "regex"
        ? await matchThimbleRegex(
            request.rule,
            rows.map((row) =>
              regexRowText(row, files.find((file) => row.ref.startsWith(`${file}#`))!)
            ),
            signal
          )
        : [];
    return withLabelLock(
      directory,
      async () => {
        const old = await loadLabel(directory, name);
        const same =
          old?.kind === request.action &&
          old.rule === request.rule &&
          old.in === pattern &&
          JSON.stringify(old.values) === JSON.stringify(values);
        const label: ThimbleLabel = same
          ? old
          : {
              name,
              version: old ? old.version + 1 : 1,
              kind: request.action,
              rule: request.rule!,
              in: pattern,
              values,
              units: Object.create(null),
              checks: Object.fromEntries(
                Object.entries(old?.checks ?? {}).filter(([, check]) => values.includes(check.v))
              ),
              created: Date.now() / 1000,
              rev: old?.rev ?? 0,
              versions: old?.versions ?? [],
            };
        let added = 0;
        for (const [index, row] of rows.entries()) {
          if (label.units[row.ref]) continue;
          label.units[row.ref] =
            request.action === "regex"
              ? { v: hits[index] ? values[0] : values.at(-1)!, c: 1, by: "regex" }
              : { v: null, wait: true };
          added++;
        }
        label.checks = Object.fromEntries(
          Object.entries(label.checks).filter(([ref]) => label.units[ref])
        );
        label.files = [...new Set([...(same ? (label.files ?? []) : []), ...files])];
        label.matched = matched;
        label.trial = true;
        label.limit = limit;
        label.seed = 0;
        label.sessions = [
          ...(label.sessions ?? []).filter((value) => value !== session).slice(-49),
          session,
        ];
        if (request.action === "prompt") {
          const waiting = Object.values(label.units).filter((unit) => unit.wait).length;
          label.run = { state: waiting ? "asked" : "done", asked: Date.now() / 1000, waiting };
        }
        await saveLabel(directory, label, signal);
        return { name, ...labelStatus(label), added, errors: [] };
      },
      signal
    );
  }
  const label = await loadLabel(directory, name);
  if (!label) throw new Error(`Thimble label: no label ${name}`);
  // Validate saved sources before every named operation; no agent can fetch a
  // source through a saved reference whose target was subsequently moved outside.
  for (const file of new Set(Object.keys(label.units).map((ref) => fileForRef(label, ref)))) {
    try {
      await readThimbleSource(root, file, signal);
    } catch (error) {
      if (!(error instanceof Error && "code" in error && error.code === "ENOENT")) throw error;
    }
  }
  if (request.action === "list") return { ...labelHead(label), definition: label.rule };
  if (request.action === "check") {
    return withLabelLock(
      directory,
      async () => {
        const current = await loadLabel(directory, name);
        const ref = request.ref ?? "";
        if (!current?.units[ref])
          throw new Error(`Thimble label: ${ref} is not one of ${name}'s records`);
        if (request.value === undefined)
          throw new Error("Thimble label correction requires a value");
        const value = request.value === "-" ? null : request.value;
        if (value !== null && !current.values.includes(value))
          throw new Error(`Thimble label: ${value} is not a value of ${name}`);
        if (value === null) delete current.checks[ref];
        else current.checks[ref] = { v: value, was: current.units[ref].v, at: Date.now() / 1000 };
        await saveLabel(directory, current, signal);
        return { label: current, ref, was: current.units[ref].v, now: value };
      },
      signal
    );
  }
  const refs = Object.keys(label.units).filter((ref) => !label.units[ref].out);
  if (request.action === "waiting") {
    const waiting = refs.filter((ref) => label.units[ref].wait);
    const rows = await labelRows(root, label, waiting, signal);
    const units = waiting.flatMap((ref) =>
      rows.has(ref) ? [{ ref, text: recordText(rows.get(ref)!, 4000, label.rule ?? "") }] : []
    );
    const first: typeof units = [];
    let size = 0;
    for (const unit of units) {
      if (first.length && (first.length >= 50 || size + unit.text.length + 40 > 36_000)) break;
      first.push(unit);
      size += unit.text.length + 40;
    }
    return {
      name,
      version: label.version,
      definition: label.rule ?? "",
      values: label.values,
      units: first,
      waiting: units.length,
      gone: waiting.filter((ref) => !rows.has(ref)),
      batches: first.length ? [first.map((unit) => unit.ref)] : [],
    };
  }
  const ordered = [
    ...refs.filter((ref) => !label.checks[ref]),
    ...refs.filter((ref) => label.checks[ref]),
  ].slice(0, 100);
  const rows = await labelRows(root, label, ordered, signal);
  return {
    label: labelHead(label),
    value: null,
    at: 0,
    total: refs.length,
    records: ordered.map((ref, i) => {
      const unit = label.units[ref],
        check = label.checks[ref],
        row = rows.get(ref);
      const record: ThimbleRecord = {
        ref,
        i,
        value: check?.v ?? unit.v,
        by: check ? "analyst" : (unit.by ?? null),
      };
      if (check) {
        record.checked = true;
        record.was = check.was;
      }
      if (unit.wait) record.waiting = true;
      if (unit.err) record.error = unit.err;
      if (unit.why) record.reason = unit.why;
      if (unit.by === "model" && !check) record.confidence = unit.c ?? null;
      if (row) {
        record.words = recordText(row, 240);
        record.text = recordText(row, 1200);
      } else record.missing = "the record is no longer in its file";
      return record;
    }),
  };
}

const answerRequestSchema = Type.Object({
  name: Type.String(),
  answers: Type.Object({
    values: Type.Optional(Type.Record(Type.String(), thimbleJsonSchema)),
    failed: Type.Optional(Type.Record(Type.String(), thimbleJsonSchema)),
    run: Type.Optional(Type.Record(Type.String(), thimbleJsonSchema)),
  }),
});

/** Apply only answers to waiting records; human corrections remain separate from model values. */
export async function saveThimbleLabelAnswers(
  root: string,
  directory: string,
  payload: ThimbleJson,
  signal?: AbortSignal
): Promise<ThimbleJson> {
  const request = Value.Parse(answerRequestSchema, payload);
  return withLabelLock(
    directory,
    async () => {
      const label = await loadLabel(directory, request.name);
      if (!label) throw new Error(`Thimble label: no label ${request.name}`);
      await labelRows(root, label, Object.keys(label.units), signal);
      let took = 0,
        failed = 0;
      for (const [ref, answer] of Object.entries(request.answers.values ?? {})) {
        if (!label.units[ref]?.wait) continue;
        const item: ThimbleRecord = Value.Check(
          Type.Record(Type.String(), thimbleJsonSchema),
          answer
        )
          ? answer
          : { value: answer };
        const raw =
          item.value === null || item.value === undefined ? "" : String(item.value).trim();
        const value = label.values.includes(raw)
          ? raw
          : label.values.find(
              (value) => value.toLowerCase() === raw.replace(/^["'`]+|["'`]+$/g, "").toLowerCase()
            );
        if (!value) {
          label.units[ref] = {
            v: null,
            by: "model",
            err: "the model gave a value outside the label's allowed values",
          };
          failed++;
        } else {
          label.units[ref] = {
            v: value,
            by: "model",
            c: Value.Check(Type.Number(), item.confidence) ? item.confidence : null,
          };
          if (item.reason) label.units[ref].why = String(item.reason).slice(0, 300);
          took++;
        }
      }
      for (const [ref, why] of Object.entries(request.answers.failed ?? {})) {
        if (label.units[ref]?.wait) {
          label.units[ref] = { v: null, by: "model", err: String(why).slice(0, 300) };
          failed++;
        }
      }
      label.run = { ...(label.run ?? {}), ...(request.answers.run ?? {}), at: Date.now() / 1000 };
      if (!Object.values(label.units).some((unit) => unit.wait) && label.run.state !== "failed")
        label.run.state = "done";
      await saveLabel(directory, label, signal);
      return { label, took, failed };
    },
    signal
  );
}
