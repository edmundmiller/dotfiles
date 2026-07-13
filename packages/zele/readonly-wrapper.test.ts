import { afterAll, beforeAll, expect, test } from "bun:test";
import { chmod, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

const wrapper = join(import.meta.dir, "readonly-wrapper.sh");
let fixtureDir: string;
let fakeZele: string;

beforeAll(async () => {
  fixtureDir = await mkdtemp(join(tmpdir(), "zele-readonly-"));
  fakeZele = join(fixtureDir, "zele-real");
  await writeFile(fakeZele, "#!/bin/sh\nprintf 'REAL:%s\\n' \"$*\"\n");
  await chmod(fakeZele, 0o755);
});

afterAll(async () => {
  await rm(fixtureDir, { recursive: true, force: true });
});

function run(args: string[]) {
  return Bun.spawnSync([wrapper, ...args], {
    env: { ...process.env, ZELE_REAL_BIN: fakeZele },
    stdout: "pipe",
    stderr: "pipe",
  });
}

test("blocks outbound mail but preserves reads and drafts", () => {
  const blocked = [
    [],
    ["mail", "send", "--to", "nobody@example.invalid"],
    ["mail", "reply", "INBOX:1", "--body", "hello"],
    ["mail", "forward", "INBOX:1", "--to", "nobody@example.invalid"],
    ["draft", "send", "draft-1"],
    ["mail", "unsubscribe", "INBOX:1"],
    ["--account", "me@example.com", "mail", "send", "--to", "nobody@example.invalid"],
  ];

  for (const args of blocked) {
    const result = run(args);
    expect(result.exitCode).not.toBe(0);
    expect(result.stderr.toString()).toContain("read-only");
    expect(result.stdout.toString()).not.toContain("REAL:");
  }

  const allowed = [
    ["whoami"],
    ["mail", "list", "--limit", "100"],
    ["mail", "reply", "INBOX:1", "--body", "hello", "--draft"],
    ["mail", "forward", "INBOX:1", "--to", "nobody@example.invalid", "--draft"],
    ["mail", "unsubscribe", "INBOX:1", "--dry-run"],
    ["--account", "me@example.com", "mail", "read", "INBOX:1"],
    ["--help"],
  ];

  for (const args of allowed) {
    const result = run(args);
    expect(result.exitCode).toBe(0);
    expect(result.stdout.toString()).toContain("REAL:");
  }
});
