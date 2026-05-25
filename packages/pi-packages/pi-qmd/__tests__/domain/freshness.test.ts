import { execFileSync } from "node:child_process";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { check_freshness } from "../../domain/freshness.js";
import { collection_key_from_repo_root } from "../../domain/repo-binding.js";

let tmp_dir: string;
let repo_dir: string;
let counter = 0;

function git(args: string[]) {
  execFileSync("git", ["-c", "commit.gpgsign=false", ...args], {
    cwd: repo_dir,
    stdio: "pipe",
  });
}

beforeAll(async () => {
  tmp_dir = await mkdtemp(path.join(os.tmpdir(), "qmd-freshness-test-"));
});

afterAll(async () => {
  await rm(tmp_dir, { recursive: true, force: true });
});

beforeEach(async () => {
  counter += 1;
  repo_dir = path.join(tmp_dir, `repo-${counter}`);
  await mkdir(repo_dir, { recursive: true });
  git(["init"]);
  git(["config", "user.email", "qmd@example.com"]);
  git(["config", "user.name", "QMD Test"]);
  await writeFile(path.join(repo_dir, "README.md"), "# Fresh\n");
  git(["add", "README.md"]);
  git(["commit", "-m", "init"]);
});

describe("check_freshness", () => {
  it("returns fresh when no markdown changed", async () => {
    const commit = execFileSync("git", ["rev-parse", "HEAD"], {
      cwd: repo_dir,
      encoding: "utf8",
    }).trim();
    const result = await check_freshness({
      schema_version: 1,
      repo_root: repo_dir,
      collection_key: collection_key_from_repo_root(repo_dir),
      last_indexed_at: new Date().toISOString(),
      last_indexed_commit: commit,
      created_at: new Date().toISOString(),
    });

    expect(result.status).toBe("fresh");
  });

  it("returns stale when a markdown file changes", async () => {
    const commit = execFileSync("git", ["rev-parse", "HEAD"], {
      cwd: repo_dir,
      encoding: "utf8",
    }).trim();
    await writeFile(path.join(repo_dir, "README.md"), "# Changed\n");

    const result = await check_freshness({
      schema_version: 1,
      repo_root: repo_dir,
      collection_key: collection_key_from_repo_root(repo_dir),
      last_indexed_at: new Date().toISOString(),
      last_indexed_commit: commit,
      created_at: new Date().toISOString(),
    });

    expect(result.status).toBe("stale");
    if (result.status === "stale") {
      expect(result.changed_paths).toContain("README.md");
    }
  });
});
