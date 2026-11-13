import type { ExtensionContext } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";
import { Value } from "typebox/value";
import { runThimbleEngine } from "./thimble-engine.js";
import { thimbleRecordSchema, type ThimbleJson, type ThimbleRecord } from "./thimble-json.js";
import { thimbleBranchRecords, thimbleSeenCalls } from "./thimble-session.js";

/** Inspector sections load saved data on demand, never model-generated findings. */
export const thimbleInspectorSections = [
  "claims",
  "citations",
  "cards",
  "labels",
  "coverage",
] as const;

/** A nested group is a card snapshot or a session-scoped label. */
export interface ThimbleInspectionLocation {
  section: (typeof thimbleInspectorSections)[number];
  group?: string;
}

/** A selectable finding retains its source, verdict, and optional human correction. */
export interface ThimbleInspectionItem {
  id: string;
  label: string;
  status: string;
  detail: string;
  format: "markdown" | "text";
  open?: ThimbleInspectionLocation;
  correction?: { name: string; ref: string };
}

/** An inspection page includes an actionable empty state and optional scope note. */
export interface ThimbleInspectionPage {
  title: string;
  note: string;
  empty: string;
  items: ThimbleInspectionItem[];
}

function record(value: ThimbleJson) {
  return Value.Parse(thimbleRecordSchema, value);
}

function records(value: ThimbleJson | undefined) {
  return Value.Parse(Type.Array(thimbleRecordSchema), value ?? []);
}

function pretty(value: ThimbleJson | undefined) {
  return JSON.stringify(value, null, 2) ?? "Not recorded";
}

function fenced(text: string, language = "") {
  const fence = "`".repeat(
    Math.max(3, ...[...text.matchAll(/`+/g)].map((match) => match[0].length + 1))
  );
  return `${fence}${language}\n${text}\n${fence}`;
}

function citationDetail(check: ThimbleRecord) {
  return [
    "## Claim",
    String(check.sentence ?? check.words),
    `## Evidence · ${check.file}:${check.line}`,
    fenced(String(check.passage ?? "No saved passage")),
    "## Verdict",
    String(check.reason ?? "The evidence did not pass deterministic validation."),
    "Model verdicts are not proof. This is the saved passage, not a fresh read of the file.",
    "## Validation and usage",
    fenced(
      pretty({
        deterministic: check.deterministic ?? null,
        model: check.model ?? null,
        usage: check.usage ?? null,
      }),
      "json"
    ),
  ].join("\n\n");
}

/** Load one inspector page from the active branch or upstream store without model calls. */
export async function loadThimbleInspection(
  ctx: ExtensionContext,
  location: ThimbleInspectionLocation,
  signal?: AbortSignal
): Promise<ThimbleInspectionPage> {
  const branch = ctx.sessionManager.getBranch();
  if (location.section === "claims" || location.section === "citations") {
    const checks = thimbleBranchRecords(branch, "thimble:check").map(record);
    const claims = thimbleBranchRecords(branch, "thimble:claim").map(record);
    const citations = location.section === "citations";
    return {
      title: citations ? "Citation checks" : "Claims",
      note: "Active branch · saved evidence only",
      empty: citations
        ? "No citation checks on this branch. Ask Pi to use thimble_cite."
        : "No saved claims on this branch. Run /thimble claims extract to extract them explicitly.",
      items: (citations ? checks : claims).map((item, index) => {
        const check = citations
          ? item
          : [...checks].reverse().find((check) => check.sentence === item.words);
        return {
          id: String(index),
          label: String(item.sentence ?? item.words),
          status: String(check?.status ?? "unverified"),
          format: "markdown",
          detail: check
            ? citationDetail(check)
            : `## Claim\n\n${item.words}\n\nNo matching citation check is saved. This claim is unverified.`,
        };
      }),
    };
  }
  if (location.section === "cards") {
    const cards = thimbleBranchRecords(branch, "thimble:card").map(record);
    if (location.group !== undefined) {
      const card = cards[Number(location.group)];
      if (!card) throw new Error("Thimble card is no longer on this branch");
      return {
        title: String(card.title),
        note: "Saved snapshot · source file changes do not alter these rows",
        empty: "This card has no rows.",
        items: records(card.rows).map((row, index) => ({
          id: String(index),
          label: `${index + 1}. ${JSON.stringify(row)}`,
          status: "snapshot",
          detail: pretty(row),
          format: "text",
        })),
      };
    }
    return {
      title: "Cards",
      note: "Active branch · Enter opens a card's complete rows",
      empty: "No cards on this branch. Ask Pi to use thimble_card with a local JSON file.",
      items: cards.map((card, index) => ({
        id: String(index),
        label: String(card.title),
        status: String(card.kind),
        detail: `${card.title}\n\n${card.text}\n\nSource: ${card.data}\n${records(card.rows).length} saved rows · Enter to inspect`,
        format: "text",
        open: { section: "cards", group: String(index) },
      })),
    };
  }
  if (location.section === "labels") {
    if (location.group !== undefined) {
      const page = record(
        await runThimbleEngine(ctx, "label", { action: "records", name: location.group }, signal)
      );
      return {
        title: location.group,
        note: `Session labels · showing ${records(page.records).length} of ${page.total} records · c corrects selected record`,
        empty: "This label has no records.",
        items: records(page.records).map((item) => ({
          id: String(item.ref),
          label: String(item.ref),
          status: `${item.value ?? "unassigned"}${item.checked ? " · checked" : ""}`,
          format: "markdown",
          correction: { name: location.group!, ref: String(item.ref) },
          detail: [
            "## Record",
            String(item.ref),
            "## Text",
            fenced(String(item.text ?? item.words ?? item.missing ?? "No saved text")),
            "## Label",
            `Value: ${item.value ?? "unassigned"} · By: ${item.by ?? "unknown"}`,
            String(item.reason ?? ""),
            "## Record details",
            fenced(pretty(item), "json"),
          ].join("\n\n"),
        })),
      };
    }
    const labels = records(await runThimbleEngine(ctx, "label", { action: "list" }, signal));
    return {
      title: "Labels",
      note: "Session-scoped · shared between branches · Enter opens records",
      empty:
        "No labels in this session. Ask Pi to use thimble_label with a regex or model definition.",
      items: labels.map((label) => ({
        id: String(label.name),
        label: String(label.name),
        status: `${label.checked} checked`,
        format: "markdown",
        open: { section: "labels", group: String(label.name) },
        detail: `## Definition\n\n${label.rule}\n\n## Counts and scope\n\n${fenced(pretty(label), "json")}`,
      })),
    };
  }
  const report = record(
    await runThimbleEngine(ctx, "coverage", { seen: thimbleSeenCalls(branch, ctx.cwd) }, signal)
  );
  return {
    title: "Coverage",
    note: "Active branch · visible reads, rule/model labels · incomplete coverage",
    empty: "There are no files in this working folder.",
    items: [
      {
        id: "summary",
        label: "Session summary",
        status: "coverage",
        detail: String(report.summary),
        format: "text",
      },
      ...records(report.files).map(
        (file): ThimbleInspectionItem => ({
          id: String(file.path),
          label: String(file.path),
          status: String(file.status),
          detail: `## File coverage\n\n${file.path}\n\n${fenced(pretty(file), "json")}\n\nCoverage records what was exposed, not whether the model understood it.`,
          format: "markdown",
        })
      ),
    ],
  };
}
