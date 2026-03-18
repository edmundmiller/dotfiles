/**
 * Integration tests: pi-qmd slash command flow.
 *
 * Verifies the extension registers /qmd with Pi's real command pipeline and
 * reports repo binding state through the pi-test-harness in controlled temp repos.
 */

import { afterEach, beforeEach, describe, expect, it } from "bun:test";
import { createTestSession, when, type TestSession } from "@marcfargas/pi-test-harness";
import { execSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { add_collection, close_store } from "../pi-qmd/core/qmd-store.js";
import { get_repo_head_commit } from "../pi-qmd/domain/freshness.js";
import { collection_key_from_repo_root, write_repo_marker } from "../pi-qmd/domain/repo-binding.js";

const EXTENSION = path.resolve(import.meta.dir, "../pi-qmd/index.ts");

function setup_git_repo(): string {
  const temp_dir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-qmd-harness-repo-"));
  const repo_dir = fs.realpathSync(temp_dir);
  fs.writeFileSync(path.join(repo_dir, "README.md"), "# QMD Harness Test\n", "utf8");
  fs.mkdirSync(path.join(repo_dir, "docs"), { recursive: true });
  fs.writeFileSync(path.join(repo_dir, "docs", "guide.md"), "# Guide\n", "utf8");

  execSync("git init", { cwd: repo_dir, stdio: "ignore" });
  execSync('git config user.name "Test User"', { cwd: repo_dir, stdio: "ignore" });
  execSync('git config user.email "test@example.com"', { cwd: repo_dir, stdio: "ignore" });
  execSync("git add .", { cwd: repo_dir, stdio: "ignore" });
  execSync('git commit -m "init"', { cwd: repo_dir, stdio: "ignore" });

  return repo_dir;
}

function notify_texts(t: TestSession): string[] {
  return t.events
    .uiCallsFor("notify")
    .map((call) => (typeof call.args[0] === "string" ? call.args[0] : String(call.args[0] ?? "")));
}

describe("pi-qmd harness coverage", () => {
  let t: TestSession;
  let repo_dir: string;
  let cache_dir: string;
  let saved_xdg_cache_home: string | undefined;

  beforeEach(() => {
    repo_dir = setup_git_repo();
    cache_dir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-qmd-harness-cache-"));
    saved_xdg_cache_home = process.env.XDG_CACHE_HOME;
    process.env.XDG_CACHE_HOME = cache_dir;
  });

  afterEach(async () => {
    t?.dispose();
    await close_store();

    if (saved_xdg_cache_home === undefined) {
      delete process.env.XDG_CACHE_HOME;
    } else {
      process.env.XDG_CACHE_HOME = saved_xdg_cache_home;
    }

    if (fs.existsSync(repo_dir)) {
      fs.rmSync(repo_dir, { recursive: true, force: true });
    }
    if (fs.existsSync(cache_dir)) {
      fs.rmSync(cache_dir, { recursive: true, force: true });
    }
  });

  it("runs /qmd status and reports a repo as not indexed", async () => {
    t = await createTestSession({
      extensions: [EXTENSION],
      cwd: repo_dir,
    });

    await t.run(when("/qmd status", []));

    const texts = notify_texts(t);
    expect(texts).toHaveLength(1);
    expect(texts[0]).toContain("QMD status: not indexed");
    expect(texts[0]).toContain(`repo_root: ${repo_dir}`);
    expect(texts[0]).toContain("Next step: run /qmd init");
  });

  it("runs /qmd status and reports an indexed repo as fresh", async () => {
    const collection_key = collection_key_from_repo_root(repo_dir);
    await add_collection({ collection_key, repo_root: repo_dir });

    const last_indexed_commit = await get_repo_head_commit(repo_dir);
    if (!last_indexed_commit) {
      throw new Error("expected git HEAD commit for harness test repo");
    }

    const now = new Date().toISOString();
    await write_repo_marker(repo_dir, {
      schema_version: 1,
      repo_root: repo_dir,
      collection_key,
      last_indexed_at: now,
      last_indexed_commit,
      created_at: now,
    });

    t = await createTestSession({
      extensions: [EXTENSION],
      cwd: repo_dir,
    });

    await t.run(when("/qmd status", []));

    const texts = notify_texts(t);
    expect(texts).toHaveLength(1);
    expect(texts[0]).toContain("QMD status: indexed");
    expect(texts[0]).toContain(`repo_root: ${repo_dir}`);
    expect(texts[0]).toContain(`collection_key: ${collection_key}`);
    expect(texts[0]).toContain("binding_source: marker");
    expect(texts[0]).toContain("freshness: fresh");
  });
});
