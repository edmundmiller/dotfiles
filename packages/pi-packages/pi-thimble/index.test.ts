import { afterEach, beforeEach, expect, test } from "bun:test";
import {
  SessionManager,
  createReadTool,
  initTheme,
  type ExtensionAPI,
  type ExtensionContext,
  type ExtensionToolContext,
  type ToolDefinition,
  type Theme,
} from "@earendil-works/pi-coding-agent";
import { getKeybindings, visibleWidth, type TUI, type TuiMouseEvent } from "@earendil-works/pi-tui";
import { mkdtemp, readFile, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { stripVTControlCharacters } from "node:util";
import { Type } from "typebox";
import { Value } from "typebox/value";
import thimbleExtension from "./index.js";
import { runThimbleEngine } from "./thimble-engine.js";
import { loadThimbleInspection, type ThimbleInspectionPage } from "./thimble-inspection.js";
import {
  ThimbleInspector,
  showThimbleInspector,
  type ThimbleInspectorCorrection,
} from "./thimble-inspector.js";
import type { ThimbleRecord } from "./thimble-json.js";
import { thimbleSeenCalls } from "./thimble-session.js";

let root: string;
let home: string;
let session: SessionManager;
let tools: Map<string, Pick<ToolDefinition, "execute">>;
let ctx: ExtensionToolContext;
const originalHome = process.env.THIMBLE_PI_HOME;

beforeEach(async () => {
  root = await mkdtemp(join(tmpdir(), "thimble-records-"));
  home = await mkdtemp(join(tmpdir(), "thimble-state-"));
  process.env.THIMBLE_PI_HOME = home;
  session = SessionManager.inMemory(root);
  session.appendMessage({ role: "user", content: "Analyze the fixture", timestamp: Date.now() });
  tools = new Map();
  const api: Partial<ExtensionAPI> = {
    registerTool(tool) {
      // SAFETY: This fixture supplies schema-valid parameters to each named tool.
      tools.set(tool.name, { execute: tool.execute as ToolDefinition["execute"] });
    },
    registerCommand() {},
    appendEntry(type, data) {
      session.appendCustomEntry(type, data);
    },
  };
  const context: Partial<ExtensionToolContext> = { cwd: root, sessionManager: session };
  // SAFETY: These tools use only cwd and session state; model tests add their transport below.
  ctx = context as ExtensionToolContext;
  // SAFETY: All extension registration and persistence methods are implemented above.
  thimbleExtension(api as ExtensionAPI);
});

afterEach(async () => {
  if (originalHome === undefined) delete process.env.THIMBLE_PI_HOME;
  else process.env.THIMBLE_PI_HOME = originalHome;
  await rm(root, { recursive: true, force: true });
  await rm(home, { recursive: true, force: true });
});

function execute(name: string, params: ThimbleRecord) {
  const tool = tools.get(name);
  if (!tool) throw new Error(`Missing tool: ${name}`);
  return tool.execute("test", params, undefined, undefined, ctx);
}

function useModelResponse(text: string) {
  ctx.model = {
    id: "fixture",
    name: "Fixture",
    api: "anthropic-messages",
    provider: "fixture",
    baseUrl: "https://example.invalid",
    reasoning: false,
    input: ["text"],
    cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
    contextWindow: 200_000,
    maxTokens: 4096,
  };
  const registry: Partial<ExtensionContext["modelRegistry"]> = {
    async complete() {
      return {
        role: "assistant",
        content: [{ type: "text", text }],
        api: "anthropic-messages",
        provider: "fixture",
        model: "fixture",
        stopReason: "stop",
        timestamp: Date.now(),
        usage: {
          input: 17,
          output: 11,
          cacheRead: 0,
          cacheWrite: 0,
          totalTokens: 28,
          cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
        },
      };
    },
  };
  // SAFETY: The real engine and session run unchanged; only model transport is simulated.
  ctx.modelRegistry = registry as ExtensionContext["modelRegistry"];
}

function assistantCall(id: string, name: string, args: Record<string, string | number>) {
  session.appendMessage({
    role: "assistant",
    content: [{ type: "toolCall", id, name, arguments: args }],
    api: "anthropic-messages",
    provider: "anthropic",
    model: "fixture",
    usage: {
      input: 0,
      output: 0,
      cacheRead: 0,
      cacheWrite: 0,
      totalTokens: 0,
      cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
    },
    stopReason: "toolUse",
    timestamp: Date.now(),
  });
}

test("cards render asymmetric values and retain an immutable branch snapshot", async () => {
  await writeFile(
    join(root, "rows.json"),
    JSON.stringify([
      { name: "alpha", count: 3 },
      { name: "beta日本語", count: 12 },
    ])
  );
  const base = session.getLeafId();
  const result = await execute("thimble_card", {
    title: "Counts",
    data: "rows.json",
    kind: "bars",
    columns: ["name", "count"],
  });
  expect(result.content[0]).toMatchObject({
    type: "text",
    text: expect.stringMatching(/alpha\s+█{6} 3\nbeta日本語\s+█{24} 12/),
  });
  const table = await execute("thimble_card", {
    title: "Counts table",
    data: "rows.json",
    kind: "table",
    columns: ["name", "count"],
  });
  // Japanese glyphs occupy two terminal columns, not one JavaScript character.
  expect(table.content[0]).toMatchObject({
    text: expect.stringContaining(`beta日本語${" ".repeat(15)}│ 12`),
  });
  await writeFile(join(root, "rows.json"), "[]");
  const saved = session
    .getBranch()
    .find((entry) => entry.type === "custom" && entry.customType === "thimble:card");
  expect(saved).toMatchObject({
    data: {
      rows: [
        { name: "alpha", count: 3 },
        { name: "beta日本語", count: 12 },
      ],
    },
  });
  session.branch(base!);
  expect(
    session
      .getBranch()
      .some((entry) => entry.type === "custom" && entry.customType === "thimble:card")
  ).toBe(false);
});

test("cards reject escaping symlinks and invalid bar values", async () => {
  await writeFile(join(home, "outside.json"), '[{"n":7}]');
  await symlink(join(home, "outside.json"), join(root, "link.json"));
  await expect(
    execute("thimble_card", { title: "Outside", data: "link.json", kind: "table", columns: ["n"] })
  ).rejects.toThrow("symlink targets");
  await writeFile(join(root, "bad.json"), '[{"name":"x","n":-1}]');
  await expect(
    execute("thimble_card", {
      title: "Invalid",
      data: "bad.json",
      kind: "bars",
      columns: ["name", "n"],
    })
  ).rejects.toThrow("non-negative numeric");
});

test("coverage translates actual partial Pi reads and drops rewound/failed calls", async () => {
  await writeFile(join(root, "record.txt"), "one\ntwo\nthree\nfour\nfive\nsix\n");
  const tool = createReadTool(root);
  const input = { path: "record.txt", offset: 3, limit: 2 };
  assistantCall("partial", "read", input);
  const result = await tool.execute("partial", input);
  session.appendMessage({
    role: "toolResult",
    toolCallId: "partial",
    toolName: "read",
    ...result,
    isError: false,
    timestamp: Date.now(),
  });
  const leaf = session.getLeafId();
  assistantCall("failed", "read", { path: "failed.txt" });
  session.appendMessage({
    role: "toolResult",
    toolCallId: "failed",
    toolName: "read",
    content: [{ type: "text", text: "Permission denied" }],
    isError: true,
    timestamp: Date.now(),
  });
  expect(thimbleSeenCalls(session.getBranch(), root)).toMatchObject([
    { tool: "Read", from: 3, to: 4 },
  ]);
  assistantCall("other", "read", { path: "record.txt" });
  session.appendMessage({
    role: "toolResult",
    toolCallId: "other",
    toolName: "read",
    content: [{ type: "text", text: "one\ntwo\nthree\nfour\nfive\nsix\n" }],
    isError: false,
    timestamp: Date.now(),
  });
  session.branch(leaf!);
  expect(thimbleSeenCalls(session.getBranch(), root)).toMatchObject([
    { tool: "Read", from: 3, to: 4 },
  ]);
});

test("native coverage rejects notice-only PDF reads and credits only supplied image content", async () => {
  await writeFile(join(root, "notice.pdf"), `${"x".repeat(60 * 1024)}\n/Type /Page\n/Type /Page\n`);
  await writeFile(join(root, "photo.png"), Buffer.from([137, 80, 78, 71, 0]));
  const input = { path: "notice.pdf" };
  assistantCall("notice", "read", input);
  const result = await createReadTool(root).execute("notice", input);
  expect(result.content).toEqual([
    { type: "text", text: expect.stringMatching(/^\[Line 1 is .*exceeds .*limit\./) },
  ]);
  session.appendMessage({
    role: "toolResult",
    toolCallId: "notice",
    toolName: "read",
    ...result,
    isError: false,
    timestamp: Date.now(),
  });
  assistantCall("empty", "read", { path: "photo.png" });
  session.appendMessage({
    role: "toolResult",
    toolCallId: "empty",
    toolName: "read",
    content: [],
    isError: false,
    timestamp: Date.now(),
  });
  const unseen = thimbleSeenCalls(session.getBranch(), root);
  expect(unseen).toMatchObject([
    { tool: "Read", from: null, to: null, image: false },
    { tool: "Read", from: null, to: null, image: false },
  ]);
  expect(await runThimbleEngine(ctx, "coverage", { seen: unseen })).toMatchObject({
    files: [],
    total: { files: 2, seen_files: 0 },
    untouched: { path: ["notice.pdf", "photo.png"], units: [2, 1] },
  });
  assistantCall("image", "read", { path: "photo.png" });
  // An explicitly typed Pi tool-result image block is the exposure boundary;
  // no image decoder is needed to test session-to-coverage accounting.
  session.appendMessage({
    role: "toolResult",
    toolCallId: "image",
    toolName: "read",
    content: [{ type: "image", mimeType: "image/png", data: "iVBORw0KGgo=" }],
    isError: false,
    timestamp: Date.now(),
  });
  const seen = thimbleSeenCalls(session.getBranch(), root);
  expect(seen[2]).toMatchObject({ tool: "Read", from: null, to: null, image: true });
  expect(await runThimbleEngine(ctx, "coverage", { seen })).toMatchObject({
    files: [{ path: "photo.png", unit: "file", seen_units: 1 }],
    total: { files: 2, seen_files: 1 },
    untouched: { path: ["notice.pdf"], units: [2] },
  });
});

test("native coverage counts visible lines, not whole files or a sibling branch", async () => {
  await writeFile(join(root, "record.txt"), "one\ntwo\nthree\nfour\nfive\nsix");
  await writeFile(join(root, "untouched.txt"), "not opened");
  const report = await runThimbleEngine(ctx, "coverage", {
    seen: [{ tool: "Read", cwd: root, file: join(root, "record.txt"), from: 3, to: 4 }],
  });
  expect(report).toMatchObject({
    total: { files: 2, seen_files: 1 },
    files: [{ path: "record.txt", ranges: [[3, 4]], seen_units: 2, units: 6 }],
  });
  expect(JSON.stringify(report)).toContain('"seen_units":2');
});

test("regex labels persist corrections and remain isolated between sessions", async () => {
  await writeFile(
    join(root, "runs.jsonl"),
    '{"message":"PASS"}\n{"message":"FAIL"}\n{"message":"PASS"}\n'
  );
  const created = await execute("thimble_label", {
    action: "regex",
    name: "passed",
    glob: "runs.jsonl",
    rule: "PASS",
  });
  expect(JSON.stringify(created.content)).toContain('\\"yes\\": 2');
  expect(JSON.stringify(created.content)).toContain('\\"no\\": 1');
  await runThimbleEngine(ctx, "label", {
    action: "check",
    name: "passed",
    ref: "runs.jsonl#L2",
    value: "yes",
  });
  const corrected = await execute("thimble_label", { action: "list", name: "passed" });
  expect(JSON.stringify(corrected.content)).toContain('\\"checked\\": 1');
  expect(JSON.stringify(corrected.content)).toContain('\\"yes\\": 3');
  const inspected = await loadThimbleInspection(ctx, { section: "labels", group: "passed" });
  expect(inspected.items.find((item) => item.id === "runs.jsonl#L2")).toMatchObject({
    status: "yes · checked",
    correction: { name: "passed", ref: "runs.jsonl#L2" },
    detail: expect.stringContaining("FAIL"),
  });
  const other = SessionManager.inMemory(root);
  // SAFETY: Only the session manager changes; all other context capabilities stay the same.
  const isolated = { ...ctx, sessionManager: other } as ExtensionContext;
  expect(await runThimbleEngine(isolated, "label", { action: "list" })).toEqual([]);
  expect(await readFile(join(root, "runs.jsonl"), "utf8")).toContain('"FAIL"');
});

test("prompt labels apply simulated answers through the native store", async () => {
  await writeFile(join(root, "runs.jsonl"), '{"result":"PASS"}\n{"result":"FAIL"}\n');
  useModelResponse(
    JSON.stringify({
      values: {
        "runs.jsonl#L1": { value: "yes", reason: "Passed" },
        "runs.jsonl#L2": { value: "no", reason: "Failed" },
      },
    })
  );
  const labeled = await execute("thimble_label", {
    action: "prompt",
    name: "passed",
    glob: "runs.jsonl",
    rule: "Did the run pass?",
  });
  expect(JSON.stringify(labeled.content)).toContain('\\"waiting\\": 0');
  expect(JSON.stringify(labeled.content)).toContain('\\"yes\\": 1');
  expect(JSON.stringify(labeled.content)).toContain('\\"no\\": 1');
  const coverage = await runThimbleEngine(ctx, "coverage", { seen: [] });
  expect(coverage).toMatchObject({ files: [{ path: "runs.jsonl", model: 2 }] });
});

test("label sources stay confined after glob normalization and later symlink replacement", async () => {
  await writeFile(join(home, "outside.jsonl"), '{"message":"PRIVATE"}\n');
  await symlink(join(home, "outside.jsonl"), join(root, "link.jsonl"));
  await symlink(home, join(root, "linked"));
  for (const glob of [
    "link.jsonl",
    " link.jsonl",
    "link.jsonl ",
    "link.jsonl #",
    "linked/*.jsonl",
  ]) {
    await expect(
      runThimbleEngine(ctx, "label", { action: "regex", name: "escaped", glob, rule: "PRIVATE" })
    ).rejects.toThrow("outside the working folder");
  }
  await writeFile(join(root, "runs.jsonl"), '{"message":"PASS"}\n');
  for (const action of ["regex", "prompt"]) {
    await runThimbleEngine(ctx, "label", {
      action,
      name: action,
      glob: " runs.jsonl ",
      rule: "PASS",
    });
    const safe = await runThimbleEngine(ctx, "label", { action: "records", name: action });
    expect(safe).toMatchObject({ records: [{ text: expect.stringContaining("PASS") }] });
  }
  await rm(join(root, "runs.jsonl"));
  await symlink(join(home, "outside.jsonl"), join(root, "runs.jsonl"));
  for (const name of ["regex", "prompt"]) {
    await expect(runThimbleEngine(ctx, "label", { action: "records", name })).rejects.toThrow(
      "outside the working folder"
    );
  }
  await expect(
    runThimbleEngine(ctx, "label", { action: "waiting", name: "prompt" })
  ).rejects.toThrow("outside the working folder");
});

test.each([
  ["hash#link.jsonl", "hash*.jsonl", "outside.jsonl"],
  ["dir#sources", "dir*/*.jsonl", "."],
])("labels reject outward symlinks with a literal hash in %s", async (link, glob, target) => {
  await writeFile(join(home, "outside.jsonl"), '{"message":"PRIVATE"}\n');
  await symlink(join(home, target), join(root, link));
  for (const action of ["regex", "prompt"]) {
    await expect(
      runThimbleEngine(ctx, "label", { action, name: "escaped", glob, rule: "PRIVATE" })
    ).rejects.toThrow("outside the working folder");
  }
  await writeFile(join(root, "safe#local.jsonl"), '{"message":"PASS"}\n');
  expect(
    await runThimbleEngine(ctx, "label", {
      action: "regex",
      name: "safe",
      glob: "safe*.jsonl",
      rule: "PASS",
    })
  ).toMatchObject({ counts: { yes: 1 }, records: 1 });
});

test("literal none is a human label value and only dash removes a check", async () => {
  await writeFile(join(root, "runs.jsonl"), '{"message":"PASS"}\n');
  await runThimbleEngine(ctx, "label", {
    action: "regex",
    name: "outcome",
    glob: "runs.jsonl",
    rule: "PASS",
    values: ["some", "none"],
  });
  const correction = { action: "check", name: "outcome", ref: "runs.jsonl#L1" };
  expect(await runThimbleEngine(ctx, "label", { ...correction, value: "none" })).toMatchObject({
    now: "none",
  });
  const corrected = await loadThimbleInspection(ctx, { section: "labels", group: "outcome" });
  expect(corrected.items[0]).toMatchObject({
    status: "none · checked",
    detail: expect.stringContaining("By: analyst"),
  });
  await expect(runThimbleEngine(ctx, "label", { ...correction, value: "invalid" })).rejects.toThrow(
    "not a value"
  );
  expect(await runThimbleEngine(ctx, "label", { ...correction, value: "-" })).toMatchObject({
    now: null,
  });
  const removed = await loadThimbleInspection(ctx, { section: "labels", group: "outcome" });
  expect(removed.items[0]).toMatchObject({
    status: "some",
    detail: expect.stringContaining("By: regex"),
  });
});

test("a matching quote alone cannot override a contrary sentence verdict", async () => {
  await writeFile(join(root, "report.txt"), "There were 12 failures in the trial.\n");
  useModelResponse('{"status":"contradicted","reason":"The source limits this to the trial."}');
  const result = await execute("thimble_cite", {
    words: "12 failures",
    sentence: "There were only 12 failures in all production runs.",
    file: "report.txt",
    line: 1,
    substring: "12 failures",
  });
  expect(result.content[0]).toMatchObject({ text: expect.stringContaining('"status": "wrong"') });
  expect(session.getBranch().at(-1)).toMatchObject({
    type: "custom",
    customType: "thimble:check",
    data: {
      status: "wrong",
      deterministic: { status: "verified" },
      model: "fixture/fixture",
      passage: "1: There were 12 failures in the trial.\n2: ",
    },
  });
});

test("real evidence rejects invented quotes and mismatched numbers without a model call", async () => {
  await writeFile(join(root, "report.txt"), "There were 12 failures.\n");
  const valid = await runThimbleEngine(ctx, "evidence", {
    words: "12 failures",
    sentence: "There were 12 failures.",
    file: "report.txt",
    line: 1,
    substring: "12 failures",
  });
  expect(valid).toMatchObject({ status: "verified" });
  const wrong = await execute("thimble_cite", {
    words: "21 failures",
    sentence: "There were 21 failures.",
    file: "report.txt",
    line: 1,
    substring: "12 failures",
  });
  expect(wrong.content[0]).toMatchObject({
    text: expect.stringContaining('"status": "unconfirmed"'),
  });
  const invented = await runThimbleEngine(ctx, "evidence", {
    words: "12 failures",
    sentence: "There were 12 failures.",
    file: "report.txt",
    line: 1,
    substring: "12 successes",
  });
  expect(invented).not.toMatchObject({ status: "verified" });
});

test("inspector pairs claims only with matching saved evidence and follows the active branch", async () => {
  session.appendCustomEntry("thimble:claim", { words: "The trial had 12 failures." });
  session.appendCustomEntry("thimble:claim", { words: "Every deployment succeeded." });
  session.appendCustomEntry("thimble:check", {
    sentence: "The trial had 12 failures.",
    words: "12 failures",
    status: "verified",
    file: "trial.txt",
    line: 7,
    passage: "7: 12 failed in the trial.",
    reason: "The trial count matches.",
  });
  const leaf = session.getLeafId();
  session.appendCustomEntry("thimble:check", {
    sentence: "It is false that Every deployment succeeded.",
    words: "Every deployment succeeded.",
    status: "verified",
    passage: "Do not attach to other claims.",
  });
  const page = await loadThimbleInspection(ctx, { section: "claims" });
  expect(page.items[0]).toMatchObject({
    status: "verified",
    detail: expect.stringContaining("7: 12 failed"),
  });
  expect(page.items[1]).toMatchObject({ status: "unverified" });
  expect(page.items[1].detail).not.toContain("Do not attach");
  session.branch(leaf!);
  expect((await loadThimbleInspection(ctx, { section: "citations" })).items).toHaveLength(1);
});

test("inspector End reaches the final saved evidence inside the overlay after tall and short resizes", async () => {
  session.appendCustomEntry("thimble:claim", { words: "A long claim" });
  session.appendCustomEntry("thimble:check", {
    sentence: "A long claim",
    status: "verified",
    passage: Array.from({ length: 200 }, (_, i) => `Evidence ${i + 1}`).join("\n"),
    reason: "FINAL saved verdict",
    usage: { note: "FINAL saved usage" },
  });
  const terminal = { rows: 100, columns: 112 };
  // SAFETY: The inspector only needs terminal dimensions and requestRender from TUI.
  const tui = { terminal, requestRender() {} } as TUI;
  const theme = inspectorTheme();
  const ui: Partial<ExtensionContext["ui"]> = {
    custom: (factory, options) =>
      new Promise((resolve, reject) => {
        // SAFETY: The inspector uses only base TUI keybindings, not the agent's config methods.
        const keys = getKeybindings() as Parameters<typeof factory>[2];
        // SAFETY: The component uses only the three theme methods supplied by this fixture.
        void Promise.resolve(factory(tui, theme as Theme, keys, resolve))
          .then((view) => {
            for (const rows of [100, 34, 160]) {
              terminal.rows = rows;
              view.render(112);
              if (rows === 100) view.handleInput?.("\t");
              view.handleInput?.("\x1b[F");
              const settings = options?.overlayOptions;
              const overlay = Value.Parse(
                Type.Object({
                  maxHeight: Type.Optional(Type.Union([Type.Number(), Type.String()])),
                }),
                Value.Check(Type.Function([], Type.Unknown()), settings)
                  ? settings()
                  : (settings ?? {})
              );
              const maxHeight = overlay.maxHeight;
              // Pi clips percentage heights down to a whole number of terminal rows.
              const limit = Value.Check(Type.String(), maxHeight)
                ? Math.floor((rows * parseFloat(maxHeight)) / 100)
                : (maxHeight ?? rows);
              const visible = stripVTControlCharacters(view.render(112).slice(0, limit).join("\n"));
              expect(visible).toContain("FINAL saved usage");
              expect(visible).toContain("q close");
            }
            view.handleInput?.("q");
          })
          .catch(reject);
      }),
  };
  // SAFETY: showThimbleInspector uses only ui.custom, mode, cwd and session state here.
  await showThimbleInspector({ ...ctx, mode: "tui", ui } as ExtensionContext);
});

function inspectorTheme() {
  initTheme("dark");
  const theme: Pick<Theme, "fg" | "bold" | "inverse"> = {
    fg: (_color, text) => text,
    bold: (text) => text,
    inverse: (text) => text,
  };
  return theme;
}

function inspectorPage(): ThimbleInspectionPage {
  return {
    title: "Claims",
    note: "Saved evidence",
    empty: "No saved claims",
    items: [
      {
        id: "alpha",
        label: "Alpha trial",
        status: "verified",
        format: "text",
        detail: "ALPHA evidence",
      },
      {
        id: "beta",
        label: "Beta trial 日本語",
        status: "wrong",
        format: "text",
        detail: [
          "BETA source",
          ...Array.from({ length: 36 }, (_, i) => `Evidence line ${i + 1}`),
          "FINAL evidence",
        ].join("\n"),
        correction: { name: "outcome", ref: "runs.jsonl#L2" },
      },
    ],
  };
}

function inspectorText(view: ThimbleInspector, width = 112) {
  const lines = view.render(width);
  // Opaque rows must clear the underlying transcript, including wide characters.
  expect(lines.every((line) => visibleWidth(line) === width)).toBe(true);
  expect(lines.length).toBeLessThanOrEqual(22);
  return stripVTControlCharacters(lines.join("\n"));
}

test("inspector selection, narrow panes, native scrolling, and human correction retain the selected record", async () => {
  let correction: ThimbleInspectorCorrection | undefined;
  const view = new ThimbleInspector(inspectorTheme(), getKeybindings(), {
    location: { section: "claims" },
    height: () => 22,
    refresh() {},
    load: async () => inspectorPage(),
    done: (value) => {
      correction = value;
    },
  });
  // Rendering while the page is pending must not leave an empty cached list.
  view.render(112);
  await Promise.resolve();
  expect(inspectorText(view)).toContain("ALPHA evidence");
  view.handleInput("\x1b[B");
  expect(inspectorText(view)).toContain("BETA source");
  expect(inspectorText(view)).not.toContain("ALPHA evidence");
  expect(inspectorText(view, 48)).toContain("Beta trial 日本語");
  expect(inspectorText(view, 48)).not.toContain("BETA source");
  view.handleInput("\r");
  expect(inspectorText(view, 48)).toContain("BETA source");
  view.handleInput("\x1b[F");
  expect(inspectorText(view, 48)).toContain("FINAL evidence");
  expect(inspectorText(view, 48)).not.toContain("BETA source");
  view.handleInput("\t");
  view.invalidate();
  expect(inspectorText(view)).toContain("BETA source");
  view.handleInput("c");
  expect(correction).toEqual({
    location: { section: "claims" },
    itemId: "beta",
    name: "outcome",
    ref: "runs.jsonl#L2",
  });
});

test("inspector mouse selection and wheel scrolling use the same records as keyboard navigation", async () => {
  const view = new ThimbleInspector(inspectorTheme(), getKeybindings(), {
    location: { section: "claims" },
    height: () => 22,
    refresh() {},
    load: async () => inspectorPage(),
    done() {},
  });
  await Promise.resolve();
  const lines = view.render(112).map(stripVTControlCharacters);
  const row = lines.findIndex((line) => line.includes("Beta trial"));
  expect(row).toBeGreaterThan(0);
  const event: TuiMouseEvent = {
    type: "click",
    button: "left",
    x: 5,
    y: row,
    screenX: 5,
    screenY: row,
    width: 112,
    height: 22,
    shift: false,
    alt: false,
    ctrl: false,
  };
  view.handleMouse(event);
  expect(inspectorText(view)).toContain("BETA source");
  view.handleMouse({ ...event, type: "wheel", button: "none", x: 90, wheelDelta: 100 });
  expect(inspectorText(view)).toContain("FINAL evidence");
  expect(inspectorText(view)).not.toContain("BETA source");
  view.dispose();
});

test("switching sections ignores a late response from the previous page", async () => {
  let release: (page: ThimbleInspectionPage) => void = () => {
    throw new Error("Page resolver not ready");
  };
  const late = new Promise<ThimbleInspectionPage>((resolve) => {
    release = resolve;
  });
  const view = new ThimbleInspector(inspectorTheme(), getKeybindings(), {
    location: { section: "claims" },
    height: () => 22,
    refresh() {},
    done() {},
    load: (location) =>
      location.section === "claims"
        ? late
        : Promise.resolve({
            title: "Citations",
            note: "Saved verdicts",
            empty: "No saved citation checks",
            items: [],
          }),
  });
  view.handleInput("2");
  await Promise.resolve();
  expect(inspectorText(view)).toContain("No saved citation checks");
  release(inspectorPage());
  await Promise.resolve();
  expect(inspectorText(view)).toContain("No saved citation checks");
  expect(inspectorText(view)).not.toContain("ALPHA evidence");
  view.dispose();
});
