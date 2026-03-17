import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { afterAll, beforeAll, beforeEach, describe, expect, it } from "vitest";
import {
  build_draft_proposal,
  normalize_init_proposal,
  scan_repo,
} from "../../domain/onboarding.js";

let tmp_dir: string;
let repo_dir: string;
let counter = 0;

beforeAll(async () => {
  tmp_dir = await mkdtemp(path.join(os.tmpdir(), "qmd-onboarding-test-"));
});

afterAll(async () => {
  await rm(tmp_dir, { recursive: true, force: true });
});

beforeEach(async () => {
  counter += 1;
  repo_dir = path.join(tmp_dir, `repo-${counter}`);
  await mkdir(path.join(repo_dir, "docs"), { recursive: true });
  await mkdir(path.join(repo_dir, "extensions"), { recursive: true });
  await mkdir(path.join(repo_dir, ".pi"), { recursive: true });
  await writeFile(path.join(repo_dir, "README.md"), "# Test repo\n");
  await writeFile(path.join(repo_dir, "docs", "ARCHITECTURE.md"), "# Architecture\n");
  await writeFile(path.join(repo_dir, "extensions", "README.md"), "# Extensions\n");
});

describe("scan_repo + build_draft_proposal", () => {
  it("produces bounded scan facts and deterministic path contexts", async () => {
    const scan = await scan_repo(repo_dir);
    const draft = build_draft_proposal(scan);

    expect(scan.markdown_file_count).toBe(3);
    expect(draft.collection_key).toBe(path.basename(repo_dir));
    expect(draft.paths.map((entry) => entry.path)).toContain("docs");
    expect(draft.paths.map((entry) => entry.path)).toContain("extensions");
  });
});

describe("normalize_init_proposal", () => {
  it("normalizes duplicate paths and trims annotations", async () => {
    const proposal = await normalize_init_proposal(
      {
        root: repo_dir,
        glob_pattern: "**/*.md",
        paths: [
          { path: "docs/", annotation: "  Docs area  " },
          { path: "./docs", annotation: "Ignored duplicate" },
          { path: "/", annotation: "Root overview" },
        ],
      },
      repo_dir
    );

    expect(proposal.paths).toEqual([
      { path: "", annotation: "Root overview" },
      { path: "docs", annotation: "Docs area" },
    ]);
  });

  it("rejects paths that escape the repo root", async () => {
    await expect(
      normalize_init_proposal(
        {
          root: repo_dir,
          paths: [{ path: "../outside", annotation: "Nope" }],
        },
        repo_dir
      )
    ).rejects.toThrow("escapes the repository root");
  });
});
