import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { copyFile, mkdir, mkdtemp, rm, symlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";
import { test } from "node:test";

const exec = promisify(execFile);
const root = fileURLToPath(new URL("..", import.meta.url));

test("CLI gates reject empty scans, dark handlers, unreadable destinations and empty ledgers", async (t) => {
  const dir = await mkdtemp(join(tmpdir(), "flue-cli-test-"));
  t.after(() => rm(dir, { recursive: true, force: true }));
  await symlink(join(root, "node_modules"), join(dir, "node_modules"), "dir");
  for (const file of [
    "app.ts",
    "observability.ts",
    "observability-cli.ts",
    "evlog.config.ts",
    "package.json",
  ]) {
    await copyFile(join(root, file), join(dir, file));
  }
  const run = (...args: string[]) =>
    exec(join(root, "node_modules/.bin/tsx"), [join(dir, "observability-cli.ts"), ...args], {
      cwd: dir,
    });
  const report = JSON.parse((await run("map", "--json")).stdout);
  assert.equal(report.map.score, 100);
  assert.equal(report.map.routes.length, 1);
  assert.equal(JSON.parse((await run("doctor")).stdout).ok, true);
  await writeFile(join(dir, "app.ts"), "export default {};\n");
  await assert.rejects(run("map", "--json"));
  await writeFile(
    join(dir, "app.ts"),
    'import { Hono } from "hono"; const app = new Hono(); app.all("*", c => c.text("ok")); export default app;\n'
  );
  await assert.rejects(run("map", "--json"));
  const logs = join(dir, "logs");
  await mkdir(logs);
  await assert.rejects(run("summary", "--dir", logs), /empty ledger/);
  const blocked = join(dir, "blocked");
  await writeFile(blocked, "not a directory");
  await assert.rejects(run("doctor", "--dir", blocked));
  await writeFile(join(logs, "bad.jsonl"), '{"PRIVATE_LOG_SECRET":');
  await assert.rejects(run("summary", "--dir", logs), (cause: unknown) => {
    assert(cause instanceof Error);
    assert.match(cause.message, /Invalid observability data/);
    assert.doesNotMatch(cause.message, /PRIVATE_LOG_SECRET/);
    return true;
  });
});
