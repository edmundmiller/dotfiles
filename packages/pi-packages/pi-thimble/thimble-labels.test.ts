import { afterEach, beforeEach, expect, test } from "bun:test";
import { mkdir, mkdtemp, readFile, realpath, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
  loadThimbleLabels,
  runThimbleLabel,
  saveThimbleLabelAnswers,
  thimbleLabelDirectory,
} from "./thimble-labels.js";
import { parseThimbleJson } from "./thimble-json.js";

let root: string, home: string, directory: string;
beforeEach(async () => {
  root = await realpath(await mkdtemp(join(tmpdir(), "thimble-labels-")));
  home = await mkdtemp(join(tmpdir(), "thimble-label-home-"));
  directory = thimbleLabelDirectory(root, home, "pi-fixture");
});
afterEach(async () => {
  await rm(root, { recursive: true, force: true });
  await rm(home, { recursive: true, force: true });
});

test("label paths match the previous Python store, including Unicode folder names", () => {
  // Independently obtained with pinned kernel.store.folder_name, not this implementation.
  expect(thimbleLabelDirectory("/analysis/日本語", "/state", "pi-fixture")).toBe(
    "/state/conversations/pi-fixture/folders/analysis-----093478321bd3/labels"
  );
  expect(thimbleLabelDirectory("/analysis/records", "/state", "pi-fixture")).toBe(
    "/state/conversations/pi-fixture/folders/analysis-records-b0c82e51a626/labels"
  );
  expect(thimbleLabelDirectory("/analysis/😀", "/state", "pi-fixture")).toBe(
    "/state/conversations/pi-fixture/folders/analysis---492048cbe849/labels"
  );
});

test("a saved Python label resumes with its check, then retains it across redefinition", async () => {
  await writeFile(join(root, "rows.jsonl"), '{"text":"PASS"}\n{"text":"FAIL"}\n');
  await mkdir(directory, { recursive: true });
  await writeFile(
    join(directory, "passed.json"),
    JSON.stringify({
      name: "Passed",
      version: 1,
      kind: "regex",
      rule: "PASS",
      in: "rows.jsonl",
      values: ["yes", "no"],
      units: {
        "rows.jsonl#L1": { v: "yes", c: 1, by: "regex" },
        "rows.jsonl#L2": { v: "no", c: 1, by: "regex" },
      },
      checks: { "rows.jsonl#L2": { v: "yes", was: "no", at: 1000 } },
      created: 999,
      rev: 2,
      files: ["rows.jsonl"],
      sessions: ["pi-fixture"],
      versions: [],
    })
  );
  expect(
    await runThimbleLabel(root, directory, "pi-fixture", { action: "list", name: "Passed" })
  ).toMatchObject({ counts: { yes: 2 }, checked: 1, version: 1 });
  await runThimbleLabel(root, directory, "pi-fixture", {
    action: "regex",
    name: "Passed",
    glob: "rows.jsonl",
    rule: "FAIL",
  });
  expect(
    await runThimbleLabel(root, directory, "pi-fixture", { action: "list", name: "Passed" })
  ).toMatchObject({ counts: { no: 1, yes: 1 }, checked: 1, version: 2 });
  expect(parseThimbleJson(await readFile(join(directory, "passed.json"), "utf8"))).toMatchObject({
    checks: { "rows.jsonl#L2": { v: "yes", was: "no" } },
    rev: 3,
  });
});

test("regex labels match decoded nested values, not JSON keys, and preserve earlier values", async () => {
  await writeFile(
    join(root, "rows.jsonl"),
    '{"PASS":"no"}\n{"body":{"text":"line\\nPASS"}}\n{"body":["FAIL",2]}\n'
  );
  const definition = {
    action: "regex",
    name: "passed",
    glob: "rows.jsonl",
    rule: "(?:^|\\n)PASS$",
    values: ["hit", "middle", "miss"],
  };
  expect(await runThimbleLabel(root, directory, "pi-fixture", definition)).toMatchObject({
    counts: { hit: 1, miss: 2 },
    added: 3,
  });
  expect(await runThimbleLabel(root, directory, "pi-fixture", definition)).toMatchObject({
    counts: { hit: 1, miss: 2 },
    added: 0,
  });
});

test("prompt batches are bounded and late model answers never overwrite completed or checked records", async () => {
  await writeFile(
    join(root, "rows.jsonl"),
    Array.from({ length: 51 }, (_, i) => JSON.stringify({ n: i })).join("\n")
  );
  await runThimbleLabel(root, directory, "pi-fixture", {
    action: "prompt",
    name: "outcome",
    glob: "rows.jsonl",
    rule: "Did it pass?",
  });
  const waiting = await runThimbleLabel(root, directory, "pi-fixture", {
    action: "waiting",
    name: "outcome",
  });
  expect(waiting).toMatchObject({
    waiting: 51,
    batches: [Array.from({ length: 50 }, (_, i) => `rows.jsonl#L${i + 1}`)],
  });
  await runThimbleLabel(root, directory, "pi-fixture", {
    action: "check",
    name: "outcome",
    ref: "rows.jsonl#L1",
    value: "no",
  });
  expect(
    await saveThimbleLabelAnswers(root, directory, {
      name: "outcome",
      answers: {
        values: {
          "rows.jsonl#L1": { value: "YES", confidence: 0.7 },
          "rows.jsonl#L2": { value: "unknown" },
          "not-a-record": { value: "yes" },
        },
        failed: { "rows.jsonl#L3": "No evidence" },
      },
    })
  ).toMatchObject({ took: 1, failed: 2 });
  expect(
    await saveThimbleLabelAnswers(root, directory, {
      name: "outcome",
      answers: { values: { "rows.jsonl#L1": "no" } },
    })
  ).toMatchObject({ took: 0, failed: 0 });
  expect(
    await runThimbleLabel(root, directory, "pi-fixture", { action: "list", name: "outcome" })
  ).toMatchObject({ records: 51, waiting: 48, failed: 2, counts: { no: 1 }, checked: 1 });
  expect((await loadThimbleLabels(directory))[0].units["rows.jsonl#L1"]).toMatchObject({
    v: "yes",
    by: "model",
    c: 0.7,
  });
});

test("concurrent human checks survive atomic read-modify-write and cancellation leaves no label", async () => {
  await writeFile(join(root, "rows.jsonl"), '{"text":"PASS"}\n{"text":"FAIL"}\n');
  await runThimbleLabel(root, directory, "pi-fixture", {
    action: "regex",
    name: "outcome",
    glob: "rows.jsonl",
    rule: "PASS",
  });
  await Promise.all(
    [1, 2].map((n) =>
      runThimbleLabel(root, directory, "pi-fixture", {
        action: "check",
        name: "outcome",
        ref: `rows.jsonl#L${n}`,
        value: "no",
      })
    )
  );
  expect(
    await runThimbleLabel(root, directory, "pi-fixture", { action: "list", name: "outcome" })
  ).toMatchObject({ checked: 2, counts: { no: 2 } });
  await expect(
    runThimbleLabel(root, directory, "pi-fixture", {
      action: "regex",
      name: "invalid",
      glob: "rows.jsonl",
      rule: "(?i)PASS",
    })
  ).rejects.toThrow("does not compile");
  const controller = new AbortController();
  controller.abort();
  await expect(
    runThimbleLabel(
      root,
      directory,
      "pi-fixture",
      { action: "prompt", name: "cancelled", glob: "rows.jsonl", rule: "PASS" },
      controller.signal
    )
  ).rejects.toThrow();
  expect((await loadThimbleLabels(directory)).map((label) => label.name)).toEqual(["outcome"]);
});

test("an in-flight pathological regex can be cancelled without saving state", async () => {
  await writeFile(join(root, "rows.txt"), "a".repeat(10_000) + "!");
  await expect(
    runThimbleLabel(
      root,
      directory,
      "pi-fixture",
      {
        action: "regex",
        name: "pathological",
        glob: "rows.txt",
        rule: "(a+)+$",
      },
      AbortSignal.timeout(50)
    )
  ).rejects.toThrow();
  expect(await loadThimbleLabels(directory)).toEqual([]);
}, 2000);
