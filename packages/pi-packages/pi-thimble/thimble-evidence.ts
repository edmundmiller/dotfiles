// TypeScript adaptation of the quote-only path in Thimble's Apache-2.0 evidence engine.
import { relative } from "node:path";
import { Type } from "typebox";
import { Value } from "typebox/value";
import type { ThimbleJson, ThimbleRecord } from "./thimble-json.js";
import { readThimbleSource } from "./thimble-sources.js";

const evidenceRequestSchema = Type.Object({
  words: Type.String(),
  sentence: Type.String(),
  file: Type.String(),
  line: Type.Integer({ minimum: 1 }),
  substring: Type.String({ minLength: 1 }),
});

function plainEvidenceText(text: string) {
  return text
    .replace(/\\([!-/:-@\[-`{-~])/g, "$1")
    .replace(/\*\*|`/g, "")
    .replace(/[“”‘’']/g, '"')
    .replace(/\s+/g, " ")
    .trim();
}

function evidenceForms(text: string): string[] {
  const decoded = text.replace(/\\u[\da-f]{4}|\\["\\/bfnrt]/gi, (escape) => {
    try {
      return String(JSON.parse(`"${escape}"`));
    } catch {
      return escape;
    }
  });
  return [...new Set([text, decoded].map(plainEvidenceText))];
}

type EvidenceDay = { start: number; end: number; year: number | null; month: number; day: number };
const months = "jan feb mar apr may jun jul aug sep oct nov dec".split(" ");
const monthPattern =
  "Jan(?:uary)?|Feb(?:ruary)?|Mar(?:ch)?|Apr(?:il)?|May|June?|July?|Aug(?:ust)?|Sep(?:t(?:ember)?)?|Oct(?:ober)?|Nov(?:ember)?|Dec(?:ember)?";

function evidenceDays(text: string): EvidenceDay[] {
  const days: EvidenceDay[] = [];
  const patterns = [
    /\b(?<year>\d{4})-(?<month>\d{2})-(?<day>\d{2})(?!\d)/g,
    new RegExp(
      `\\b(?<day>\\d{1,2})(?:\\s*[–-]\\s*(?<last>\\d{1,2}))?(?:st|nd|rd|th)?\\s+(?:of\\s+)?(?<name>${monthPattern})\\b\\.?(?:,?\\s+(?<year>\\d{4})\\b)?`,
      "gi"
    ),
    new RegExp(
      `\\b(?<name>${monthPattern})\\.?\\s+(?<day>\\d{1,2})(?:st|nd|rd|th)?(?:\\s*[–-]\\s*(?<last>\\d{1,2})(?:st|nd|rd|th)?)?\\b(?:,?\\s+(?<year>\\d{4})\\b)?`,
      "gi"
    ),
  ];
  for (const pattern of patterns) {
    for (const match of text.matchAll(pattern)) {
      if (days.some((day) => day.start <= match.index && match.index < day.end)) continue;
      const fields = match.groups!;
      const value = {
        start: match.index,
        end: match.index + match[0].length,
        year: fields.year ? Number(fields.year) : null,
        month: fields.month
          ? Number(fields.month)
          : months.indexOf(fields.name.slice(0, 3).toLowerCase()) + 1,
        day: Number(fields.day),
      };
      days.push(value);
      if (fields.last) days.push({ ...value, day: Number(fields.last) });
    }
  }
  return days;
}

type EvidenceNumber = {
  value: bigint;
  places: number;
  scale: number;
  percent: boolean;
  date: boolean;
  text: string;
};
function evidenceNumbers(text: string): EvidenceNumber[] {
  const days = evidenceDays(text);
  const dateSpans = [
    ...text.matchAll(
      /\b\d{4}-\d{2}(?:-\d{2})?(?:[T ]\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?)?|\b\d{1,2}:\d{2}(?::\d{2}(?:\.\d+)?)?/g
    ),
  ];
  const numbers: EvidenceNumber[] = [];
  const pattern =
    /(?<![\w.])[-−]?\$?((?:\d{1,3}(?:,\d{3})+(?!\d)|\d+(?:_\d+)*)(?:\.\d+)?)(?:(st|nd|rd|th)\b|([kKmMB]|bn|\s(?:thousand|million|billion))\b)?/g;
  for (const match of text.matchAll(pattern)) {
    if (match[2] || days.some((day) => day.start <= match.index && match.index < day.end)) continue;
    if (
      text[match.index - 1] === "#" ||
      /[A-Za-z][-_]$/.test(text.slice(0, match.index)) ||
      /^\.\d/.test(text.slice(match.index + match[0].length))
    )
      continue;
    const digits = match[1].replace(/[,_]/g, "");
    const places = digits.split(".")[1]?.length ?? 0;
    const suffix = match[3]?.trim().toLowerCase();
    const scale = suffix
      ? suffix.startsWith("k") || suffix === "thousand"
        ? 3
        : suffix === "m" || suffix === "million"
          ? 6
          : 9
      : 0;
    numbers.push({
      value: BigInt(digits.replace(".", "")) * (/^[-−]/.test(match[0]) ? -1n : 1n),
      places,
      scale,
      percent: /^\s*(?:%|percent\b)/i.test(text.slice(match.index + match[0].length)),
      date: dateSpans.some(
        (date) => date.index <= match.index && match.index < date.index + date[0].length
      ),
      text: match[0],
    });
  }
  return numbers;
}

function sameEvidenceNumber(want: EvidenceNumber, have: EvidenceNumber) {
  // Decimal arithmetic avoids conflating adjacent integers above 2^53. Round
  // half away from zero to the precision the claim actually states.
  const wantPlaces = want.places - want.scale;
  const havePlaces = have.places - have.scale + (want.percent && !have.percent ? -2 : 0);
  if (!want.percent && have.percent) return false;
  const target = want.value;
  const shift = havePlaces - wantPlaces;
  if (shift <= 0) return target === have.value * 10n ** BigInt(-shift);
  const divisor = 10n ** BigInt(shift);
  const absolute = have.value < 0n ? -have.value : have.value;
  const rounded = ((absolute * 2n + divisor) / (divisor * 2n)) * (have.value < 0n ? -1n : 1n);
  return rounded === target;
}

function quoteFragments(words: string, sentence: string): string[] {
  const normalized = words
    .replace(/\*\*|`/g, "")
    .replace(/[“”]/g, '"')
    .replace(/\s+/g, " ")
    .trim();
  let spans = [...normalized.matchAll(/"([^\"]+)"/g)].map((match) => match[1]);
  if (!spans.length && /^['‘’].*['‘’]$/.test(normalized)) spans = [normalized.slice(1, -1)];
  if (!spans.length && plainEvidenceText(sentence).includes(`"[${normalized}]`))
    spans = [normalized];
  return spans.flatMap((span) =>
    span
      .replace(
        /(?<=\w)\[([^\[\]]*)\]|\[([^\[\]]*)\](?=\w)/g,
        (_match, a: string | undefined, b: string | undefined) => a ?? b ?? ""
      )
      .split(/…|\.\.\.|\[[^\[\]]*\]/)
      .map((fragment) => fragment.trim().replace(/^[ .,;:"]+|[ .,;:"]+$/g, ""))
      .filter((fragment) => fragment.length >= 3)
      .map(plainEvidenceText)
  );
}

/** Validate local quote evidence; semantic support still requires Pi's separate model verdict. */
export async function checkThimbleEvidence(
  root: string,
  payload: ThimbleJson,
  signal?: AbortSignal
): Promise<ThimbleRecord> {
  const request = Value.Parse(evidenceRequestSchema, payload);
  const fail = (reason: string, evidence?: ThimbleRecord): ThimbleRecord => ({
    n: 1,
    status: "failed",
    failedBy: "evidence",
    shown: request.words,
    reason,
    evidence: evidence ?? null,
  });
  const source = (await readThimbleSource(root, request.file, signal)).toString("utf8");
  const lines = source.split(/\r?\n/);
  if (lines.at(-1) === "") lines.pop();
  if (request.line > lines.length) return fail("The cited line is past the end of the file.");
  const substring = plainEvidenceText(request.substring).replace(/\s/g, "");
  const holds = (text: string) =>
    evidenceForms(text).some((form) => form.replace(/\s/g, "").includes(substring));
  let first = request.line - 1,
    last = first;
  // Preserve upstream's nearby-line recovery, shortest span and nearest first.
  const spans: Array<[number, number]> = [];
  for (let a = Math.max(0, first - 5); a <= Math.min(lines.length - 1, first + 5); a++) {
    for (let b = a; b <= Math.min(lines.length - 1, first + 5); b++) spans.push([a, b]);
  }
  spans.sort(
    (a, b) =>
      a[1] - a[0] - (b[1] - b[0]) ||
      Math.abs(a[0] - first) +
        Math.abs(a[1] - first) -
        (Math.abs(b[0] - first) + Math.abs(b[1] - first))
  );
  const found = spans.find(([a, b]) => holds(lines.slice(a, b + 1).join("\n")));
  if (found) [first, last] = found;
  const evidence: ThimbleRecord = {
    kind: "quote",
    file: request.file.startsWith("/") ? relative(root, request.file) : request.file,
    line: first === last ? String(first + 1) : `${first + 1}-${last + 1}`,
    lines: lines
      .slice(Math.max(0, first - 1), last + 2)
      .map((text, i) => ({ n: Math.max(0, first - 1) + i + 1, text: text.slice(0, 600) })),
  };
  if (!found) return fail("The cited lines do not contain the supplied substring.", evidence);
  // A long JSON line must not lend a number from an unrelated distant record.
  const hay = evidenceForms(lines.slice(first, last + 1).join("\n"))
    .map((form) => {
      if (form.length <= 20_000) return form;
      const index = form.indexOf(plainEvidenceText(request.substring));
      return index < 0
        ? ""
        : form.slice(
            Math.max(0, index - 5000),
            Math.max(index + request.substring.length, index + 15_000)
          );
    })
    .filter(Boolean);
  for (const fragment of quoteFragments(request.words, request.sentence)) {
    if (
      !hay.some(
        (text) =>
          text.includes(fragment) ||
          text.includes(fragment[0].toUpperCase() + fragment.slice(1)) ||
          text.includes(fragment[0].toLowerCase() + fragment.slice(1))
      )
    ) {
      return fail("The cited lines do not contain the quoted words.", evidence);
    }
  }
  const wantDays = evidenceDays(request.words),
    haveDays = hay.flatMap(evidenceDays);
  if (
    !wantDays.every((day) =>
      haveDays.some(
        (have) =>
          day.month === have.month &&
          day.day === have.day &&
          (day.year === null || have.year === null || day.year === have.year)
      )
    )
  ) {
    return fail("The cited lines do not show the claimed calendar day.", evidence);
  }
  const haveNumbers = hay.flatMap(evidenceNumbers);
  // Upstream quote evidence checks the stated precision even after "about";
  // its looser approximate-number rules belong to computed/card evidence.
  for (const number of evidenceNumbers(request.words)) {
    if (
      !haveNumbers.some((have) => (number.date || !have.date) && sameEvidenceNumber(number, have))
    ) {
      return fail(`The cited lines do not show the claimed number ${number.text}.`, evidence);
    }
  }
  return { n: 1, status: "verified", shown: request.words, reason: "", evidence };
}
