// Native worker entry point: no runtime imports from Pi, jiti, or TypeBox.
import { extname } from "node:path";
import { parentPort, workerData } from "node:worker_threads";
import { inflateSync } from "node:zlib";
import type { ThimbleJson, ThimbleRecord } from "./thimble-json.js";
import type {
  ThimbleSourceRow,
  ThimbleSourceWork,
  ThimbleSourceResult,
} from "./thimble-sources.js";

function parseThimbleJson(text: string): ThimbleJson {
  // JSON.parse produces only JSON scalars, arrays and records. Reject non-finite
  // numbers just as the shared JSON schema does, without loading it in a worker.
  // SAFETY: JSON grammar restricts the parsed tree to the recursive JSON union; the reviver rejects non-finite numbers.
  return JSON.parse(text, (_key, value: ThimbleJson) => {
    // oxlint-disable-next-line anti-slop/no-runtime-typeof -- Validate the native JSON parser's numeric boundary.
    if (typeof value === "number" && !Number.isFinite(value)) {
      throw new Error("Thimble source JSON contains a non-finite number");
    }
    return value;
  }) as ThimbleJson;
}

function jsonText(value: ThimbleJson): string {
  if (Array.isArray(value)) return `[${value.map(jsonText).join(", ")}]`;
  // Already parsed JSON: this discriminates the recursive JSON union, not external input.
  // oxlint-disable-next-line anti-slop/no-runtime-typeof
  if (value !== null && typeof value === "object") {
    return `{${Object.entries(value)
      .map(([key, item]) => `${JSON.stringify(key)}: ${jsonText(item)}`)
      .join(", ")}}`;
  }
  return JSON.stringify(value);
}

function jsonRow(ref: string, value: ThimbleJson): ThimbleSourceRow {
  return { ref, raw: jsonText(value), value };
}

function pointerEscape(key: string): string {
  return key.replace(/~/g, "~0").replace(/\//g, "~1");
}

function isRecord(value: ThimbleJson): value is ThimbleRecord {
  // The parser has validated every member of this JSON union at the read boundary.
  // oxlint-disable-next-line anti-slop/no-runtime-typeof
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function jsonPointerRows(file: string, value: ThimbleJson, selector: string): ThimbleSourceRow[] {
  const parts =
    selector.startsWith("/") && selector !== "/"
      ? selector
          .slice(1)
          .split("/")
          .map((part) => part.replace(/~1/g, "/").replace(/~0/g, "~"))
      : [];
  const rows: ThimbleSourceRow[] = [];
  function walk(item: ThimbleJson, index: number, pointer: string): void {
    if (index === parts.length) {
      if (Array.isArray(item))
        item.forEach((child, i) => rows.push(jsonRow(`${file}#${pointer}/${i}`, child)));
      else rows.push(jsonRow(`${file}#${pointer || "/"}`, item));
      return;
    }
    const part = parts[index];
    if (part === "*") {
      if (Array.isArray(item) || isRecord(item)) {
        for (const [key, child] of Object.entries(item))
          walk(child, index + 1, `${pointer}/${pointerEscape(key)}`);
      }
    } else if (Array.isArray(item) && /^\d+$/.test(part) && Number(part) < item.length) {
      walk(item[Number(part)], index + 1, `${pointer}/${part}`);
    } else if (isRecord(item) && Object.hasOwn(item, part)) {
      walk(item[part], index + 1, `${pointer}/${pointerEscape(part)}`);
    }
  }
  walk(value, 0, "");
  return rows;
}

function largestJsonRows(file: string, value: ThimbleJson): ThimbleSourceRow[] {
  if (Array.isArray(value)) return value.map((item, index) => jsonRow(`${file}#/${index}`, item));
  let best: { pointer: string; items: readonly ThimbleJson[] } | undefined;
  function consider(pointer: string, item: ThimbleJson): void {
    if (Array.isArray(item) && item.length > (best?.items.length ?? 0))
      best = { pointer, items: item };
  }
  if (isRecord(value)) {
    for (const [key, item] of Object.entries(value)) consider(`/${pointerEscape(key)}`, item);
    if (!best) {
      for (const [key, item] of Object.entries(value)) {
        if (isRecord(item)) {
          for (const [childKey, child] of Object.entries(item))
            consider(`/${pointerEscape(key)}/${pointerEscape(childKey)}`, child);
        }
      }
    }
  }
  const selected = best;
  return selected
    ? selected.items.map((item, i) => jsonRow(`${file}#${selected.pointer}/${i}`, item))
    : [jsonRow(`${file}#/`, value)];
}

function csvRows(file: string, text: string): ThimbleSourceRow[] {
  const delimiter = extname(file).toLowerCase() === ".tsv" ? "\t" : ",";
  const records: string[][] = [];
  let fields: string[] = [];
  let field = "";
  let quoted = false;
  let started = false;
  for (let i = 0; i < text.length; i++) {
    const char = text[i];
    if (quoted) {
      if (char === '"' && text[i + 1] === '"') {
        field += '"';
        i++;
      } else if (char === '"') quoted = false;
      else field += char;
    } else if (char === '"' && !field) {
      quoted = true;
      started = true;
    } else if (char === delimiter) {
      fields.push(field);
      field = "";
      started = true;
    } else if (char === "\n" || char === "\r") {
      if (started || field || fields.length) {
        fields.push(field);
        records.push(fields);
      } else records.push([]);
      fields = [];
      field = "";
      started = false;
      if (char === "\r" && text[i + 1] === "\n") i++;
    } else {
      field += char;
      started = true;
    }
  }
  if (started || field || fields.length) records.push([...fields, field]);
  const headers = records.shift() ?? [];
  return records
    .filter((record) => record.length > 0)
    .map((record, index) => {
      const value: ThimbleRecord = {};
      headers.forEach((header, i) =>
        Object.defineProperty(value, header, {
          value: record[i] ?? null,
          enumerable: true,
          configurable: true,
          writable: true,
        })
      );
      if (record.length > headers.length) value.null = record.slice(headers.length);
      return jsonRow(`${file}#row=${index + 1}`, value);
    });
}

function markdownRows(file: string, lines: string[]): ThimbleSourceRow[] {
  const starts = lines.flatMap((line, i) => (/^(#{1,6})\s+(.*)$/.test(line) ? [i] : []));
  if (starts[0] !== 0) starts.unshift(0);
  return starts.flatMap((start, i) => {
    const end = (starts[i + 1] ?? lines.length) - 1;
    const raw = lines.slice(start, end + 1).join("\n");
    if (!raw.trim()) return [];
    const heading = /^(#{1,6})\s+(.*)$/.exec(lines[start]);
    return [
      {
        ref: `${file}#L${start + 1}${end > start ? `-${end + 1}` : ""}`,
        raw,
        value: { heading: heading?.[2].trim() ?? "", level: heading?.[1].length ?? 0, text: raw },
      },
    ];
  });
}

function diffRows(file: string, lines: string[]): ThimbleSourceRow[] {
  const hunk = /^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$/;
  const rows: ThimbleSourceRow[] = [];
  let changedFile = "";
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (line.startsWith("+++ "))
      changedFile = line.slice(4).trim().split("\t")[0].replace(/^b\//, "");
    const match = hunk.exec(line);
    if (!match) continue;
    const start = i++;
    while (i < lines.length && !hunk.test(lines[i]) && !/^(diff |--- |\+\+\+ )/.test(lines[i])) i++;
    const body = lines.slice(start, i);
    while (body.at(-1) === "") body.pop();
    const raw = body.join("\n");
    rows.push({
      ref: `${file}#L${start + 1}-${start + body.length}`,
      raw,
      value: {
        file: changedFile,
        header: line,
        old_start: Number(match[1]),
        new_start: Number(match[3]),
        added: body.slice(1).filter((line) => line.startsWith("+")).length,
        removed: body.slice(1).filter((line) => line.startsWith("-")).length,
        text: raw,
      },
    });
    i--;
  }
  return rows;
}

type SqliteSourceValue = string | number | bigint | null | Uint8Array;
interface SqliteSourceRecord {
  [column: string]: SqliteSourceValue;
}

interface SourceDatabase {
  query(sql: string): SqliteSourceRecord[];
  close(): void;
}

async function openSourceDatabase(file: string): Promise<SourceDatabase> {
  if (process.versions.bun) {
    const { Database } = await import("bun:sqlite");
    const database = new Database(file, { readonly: true, safeIntegers: true });
    return {
      query: (sql) => database.query<SqliteSourceRecord, []>(sql).all(),
      close: () => database.close(),
    };
  }
  const { DatabaseSync } = await import("node:sqlite");
  const database = new DatabaseSync(file, { readOnly: true });
  return {
    query: (sql) => {
      const statement = database.prepare(sql);
      statement.setReadBigInts(true);
      return statement.all();
    },
    close: () => database.close(),
  };
}

function sqliteValue(value: SqliteSourceValue): ThimbleJson {
  // SQLite's native result contract is a closed union of SQL scalars and BLOBs.
  // oxlint-disable-next-line anti-slop/no-runtime-typeof
  if (value === null || typeof value === "string" || typeof value === "number") return value;
  // oxlint-disable-next-line anti-slop/no-runtime-typeof
  if (typeof value === "bigint") return Number(value);
  if (value instanceof Uint8Array) {
    // Python's default=str renders SQLite BLOBs as a bytes literal.
    const quote = value.includes(39) && !value.includes(34) ? '"' : "'";
    let body = "";
    for (const byte of value) {
      const char = String.fromCharCode(byte);
      if (char === quote || char === "\\") body += `\\${char}`;
      else if (byte === 9) body += "\\t";
      else if (byte === 10) body += "\\n";
      else if (byte === 13) body += "\\r";
      else if (byte >= 32 && byte < 127) body += char;
      else body += `\\x${byte.toString(16).padStart(2, "0")}`;
    }
    return `b${quote}${body}${quote}`;
  }
  throw new Error("Thimble SQLite returned an unsupported value");
}

async function sqliteRows(file: string, copy: string, table?: string): Promise<ThimbleSourceRow[]> {
  // The parent owns this disposable copy and removes it only after worker exit.
  const database = await openSourceDatabase(copy);
  try {
    const rows: ThimbleSourceRow[] = [];
    const tables = database
      .query(
        "select name from sqlite_master where type='table' and name not like 'sqlite_%' order by name"
      )
      .map((entry) => String(entry.name));
    if (table && !tables.includes(table)) {
      throw new Error(
        `Thimble source ${file} has no table ${JSON.stringify(table)}; its tables: ${tables.join(", ") || "none"}`
      );
    }
    for (const name of tables) {
      if (table && name !== table) continue;
      let records: SqliteSourceRecord[];
      try {
        records = database.query(`select rowid as "_rowid_", * from "${name.replace(/"/g, '""')}"`);
      } catch (error) {
        // WITHOUT ROWID tables have no upstream row refs. Other SQLite
        // failures must surface as recoverable source errors, not empty data.
        if (error instanceof Error && /no such column: rowid/i.test(error.message)) continue;
        throw error;
      }
      for (const record of records) {
        const value: ThimbleRecord = {};
        const rawFields: string[] = [];
        for (const [key, item] of Object.entries(record)) {
          if (key === "_rowid_") continue;
          const converted = sqliteValue(item);
          Object.defineProperty(value, key, {
            value: converted,
            enumerable: true,
            configurable: true,
            writable: true,
          });
          // Preserve SQL INTEGER digits in raw JSON even beyond JS number precision.
          // oxlint-disable-next-line anti-slop/no-runtime-typeof
          const rawValue = typeof item === "bigint" ? item.toString() : jsonText(converted);
          rawFields.push(`${JSON.stringify(key)}: ${rawValue}`);
        }
        rows.push({
          ref: `${file}#${name}/${record._rowid_}`,
          raw: `{${rawFields.join(", ")}}`,
          value,
        });
      }
    }
    return rows;
  } finally {
    database.close();
  }
}

async function decodeSourceRows(
  work: ThimbleSourceWork,
  text: string
): Promise<ThimbleSourceRow[]> {
  const { file, kind, selector } = work;
  const place = selector?.replace(/^#/, "");
  if (place?.startsWith("/") && kind !== "json") {
    throw new Error(
      `Thimble source ${file} is no JSON document: a JSON pointer requires a .json file`
    );
  }
  if (place && !place.startsWith("/") && kind !== "sqlite") {
    throw new Error(
      `Thimble source ${file} has no table ${JSON.stringify(place)}; its tables: none`
    );
  }
  if (kind === "sqlite") return sqliteRows(file, work.database!, place);
  if (kind === "csv") return csvRows(file, text);
  if (kind === "json") {
    const value = parseThimbleJson(text);
    return place ? jsonPointerRows(file, value, place) : largestJsonRows(file, value);
  }
  const lines = text.replace(/\r\n?/g, "\n").split("\n");
  if (lines.at(-1) === "") lines.pop();
  if (kind === "markdown") return markdownRows(file, lines);
  if (kind === "diff") return diffRows(file, lines);
  if (kind === "text")
    return lines.map((line, index) => ({ ref: `${file}#L${index + 1}`, raw: line, value: line }));
  if (kind === "jsonl")
    return lines.flatMap((line, index) => {
      if (!line.trim()) return [];
      let value: ThimbleJson;
      try {
        value = parseThimbleJson(line);
      } catch {
        value = { _text: line };
      }
      return [{ ref: `${file}#L${index + 1}`, raw: line, value }];
    });
  return [];
}

function pdfPageCount(bytes: Buffer): number {
  const count = (text: string) => [...text.matchAll(/\/Type\s*\/Page(?![a-zA-Z])/g)].length;
  const text = bytes.toString("latin1");
  let pages = count(text);
  // Page-object accounting is an estimate, not a PDF renderer. Decompression
  // runs under the worker's heap limit and deadline as well as this byte limit.
  for (const match of text.matchAll(/\/ObjStm\b[^]*?stream\r?\n([^]*?)endstream/g)) {
    try {
      pages += count(
        inflateSync(Buffer.from(match[1], "latin1"), {
          maxOutputLength: 64 * 1024 * 1024,
        }).toString("latin1")
      );
    } catch {
      // Non-Flate or damaged object streams cannot establish a page count.
    }
  }
  return Math.max(1, pages);
}

async function executeSourceWork(work: ThimbleSourceWork): Promise<ThimbleSourceResult> {
  if (work.kind === "pdf" && work.operation === "count") {
    return { rows: [], matched: pdfPageCount(Buffer.from(work.data!)), lines: 0, seed: 0 };
  }
  const text = work.data
    ? Buffer.from(work.data.buffer, work.data.byteOffset, work.data.byteLength).toString("utf8")
    : "";
  // Preserve coverage's physical LF line accounting, including CRLF and blank lines.
  const lines = text ? text.replace(/\n$/, "").split("\n").length : 0;
  const decoded = await decodeSourceRows(work, text);
  if (work.operation === "count") return { rows: [], matched: decoded.length, lines, seed: 0 };
  if (work.operation === "read") {
    const refs = work.refs ? new Set(work.refs) : undefined;
    const selected = refs ? decoded.filter((row) => refs.has(row.ref)) : decoded;
    if (selected.length > 100_000)
      throw new Error("Thimble source response exceeds 100,000 rows; use sampling or counting");
    return { rows: selected, matched: decoded.length, lines, seed: 0 };
  }
  const state = work.sample!;
  for (const row of decoded) {
    state.matched++;
    if (state.rows.length < state.limit) state.rows.push(row);
    else {
      state.seed = (Math.imul(state.seed, 1664525) + 1013904223) >>> 0;
      const index = Math.floor((state.seed / 0x100000000) * state.matched);
      if (index < state.limit) state.rows[index] = row;
    }
  }
  return { rows: state.rows, matched: state.matched, lines, seed: state.seed };
}

try {
  // SAFETY: only sourceWork constructs requests for this private entry point, with this shared protocol type.
  const work = workerData as ThimbleSourceWork;
  const result = await executeSourceWork(work);
  const bytes = Buffer.byteLength(JSON.stringify(result));
  // Check before postMessage: the parent never clones an unbounded parsed graph.
  if (bytes > work.responseByteLimit) {
    throw new Error("Thimble source worker response exceeds the 8 MiB budget");
  }
  // Native clone preserves numeric source values such as -0; JSON is only the
  // wire-size accounting, not a lossy serialization of the source row values.
  parentPort!.postMessage({ result, bytes });
} catch (error) {
  parentPort!.postMessage({
    error: `Thimble source parse/query failed: ${error instanceof Error ? error.message.slice(0, 4096) : "unknown worker failure"}`,
  });
}
