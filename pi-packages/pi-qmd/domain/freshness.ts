/** Git-based markdown freshness checks for the current QMD repo binding. */

import { execFile as exec_file_callback } from "node:child_process";
import { promisify } from "node:util";
import type { FreshnessResult, QmdRepoMarker } from "../core/types.js";

const exec_file = promisify(exec_file_callback);

export async function get_repo_head_commit(repo_root: string): Promise<string | null> {
  try {
    const { stdout } = await exec_file("git", ["-C", repo_root, "rev-parse", "HEAD"]);
    const commit = stdout.trim();
    return commit || null;
  } catch {
    return null;
  }
}

export async function check_freshness(marker: QmdRepoMarker): Promise<FreshnessResult> {
  if (!marker.last_indexed_commit) {
    return {
      status: "unknown",
      reason: "No last indexed commit is recorded in .pi/qmd.json.",
    };
  }

  try {
    await exec_file("git", ["-C", marker.repo_root, "rev-parse", "--is-inside-work-tree"]);
  } catch {
    return {
      status: "unknown",
      reason:
        "This repository is not a git worktree, so freshness could not be derived from commits.",
    };
  }

  try {
    const [{ stdout: tracked_stdout }, { stdout: untracked_stdout }] = await Promise.all([
      exec_file("git", [
        "-C",
        marker.repo_root,
        "diff",
        "--name-only",
        "--diff-filter=ACMR",
        marker.last_indexed_commit,
        "--",
        ":(glob)**/*.md",
      ]),
      exec_file("git", [
        "-C",
        marker.repo_root,
        "ls-files",
        "--others",
        "--exclude-standard",
        "--",
        "*.md",
        "**/*.md",
      ]),
    ]);

    const changed_paths = [...tracked_stdout.split("\n"), ...untracked_stdout.split("\n")]
      .map((line) => line.trim())
      .filter(Boolean);

    if (changed_paths.length === 0) {
      return { status: "fresh" };
    }

    return {
      status: "stale",
      changed_paths,
      changed_count: changed_paths.length,
    };
  } catch {
    return {
      status: "unknown",
      reason: `Git could not diff markdown files against commit ${marker.last_indexed_commit}.`,
    };
  }
}
