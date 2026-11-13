import { afterEach, beforeEach, expect, test } from "bun:test";
import { mkdtemp, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { checkThimbleEvidence } from "./thimble-evidence.js";

let root: string;
beforeEach(async () => {
  root = await mkdtemp(join(tmpdir(), "thimble-evidence-"));
});
afterEach(async () => {
  await rm(root, { force: true, recursive: true });
});

test.each([
  ["48.4%", "share=0.4843", "verified"],
  ["48.4%", "share=0.4845", "failed"],
  ["8k", "count=8,499", "verified"],
  ["8k", "count=8,500", "failed"],
  ["8m", "count=8", "failed"],
  ["8m", "count=8,000,000", "verified"],
  ["8m", "count=8,500,000", "failed"],
  ["8M", "count=8,000,000", "verified"],
  ["about 250", "count=248", "failed"],
  ["250", "count=248", "failed"],
  ["9007199254740993", "count=9007199254740992", "failed"],
  ["9007199254740993", "count=9007199254740993", "verified"],
  ["-12", "count=12", "failed"],
  ["12", "date=2026-10-12", "failed"],
  ["8–12 June 2026", "2026-06-08 through 2026-06-12", "verified"],
  ["8 June 2026", "2025-06-08", "failed"],
  ['"It failed … retry later"', "It failed. Please retry later", "verified"],
  ['"It succeeded"', "It failed", "failed"],
  ["'It failed'", "It failed", "verified"],
])("quote validation for %s against %s is %s", async (words, source, status) => {
  await writeFile(join(root, "report.txt"), source + "\n");
  expect(
    await checkThimbleEvidence(root, {
      words,
      sentence: `[${words}]`,
      file: "report.txt",
      line: 1,
      substring: source,
    })
  ).toMatchObject({ status });
});

test("decoded JSON quotes recover nearby lines, but unrelated distant numbers are not evidence", async () => {
  await writeFile(
    join(root, "report.txt"),
    'heading\n{"text":"It failed\\nretry later"}\nfooter\n'
  );
  const found = await checkThimbleEvidence(root, {
    words: '"It failed … retry later"',
    sentence: 'It said ["It failed … retry later"].',
    file: "report.txt",
    line: 1,
    substring: "It failed\nretry later",
  });
  expect(found).toMatchObject({ status: "verified", evidence: { line: "2" } });
  await writeFile(join(root, "report.txt"), `claim=12 ${"x".repeat(25_000)} 77`);
  expect(
    await checkThimbleEvidence(root, {
      words: "77",
      sentence: "[77] failed",
      file: "report.txt",
      line: 1,
      substring: "claim=12",
    })
  ).toMatchObject({ status: "failed" });
});

test("evidence reads reject outward symlinks without exposing their contents", async () => {
  await symlink("/etc/hosts", join(root, "outside.txt"));
  await expect(
    checkThimbleEvidence(root, {
      words: "localhost",
      sentence: "[localhost]",
      file: "outside.txt",
      line: 1,
      substring: "localhost",
    })
  ).rejects.toThrow("outside the working folder");
});
