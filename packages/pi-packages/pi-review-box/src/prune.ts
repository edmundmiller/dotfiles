/**
 * prune subcommand: removes pi-herdr review-boxes manifest files whose
 * workspace AND worktree are both gone.
 *
 * Output: {"removed": ["<owner>-<repo>-pr-<n>", ...]} (R6)
 * Makes zero gh calls. Tolerates missing/corrupt manifests.
 * If herdr is unavailable, exits 6 (fail safe — keep all files).
 */

import { readFile, unlink, writeFile, readdir, stat } from "node:fs/promises";
import { join } from "node:path";
import { exec, ExecError } from "./exec.ts";
import {
  defaultStateRoot,
  isReviewBoxManifest,
  type ReviewBoxManifest,
} from "../../pi-herdr/extensions/pr-review-workspace.ts";

export async function pruneReviewBoxes(): Promise<{ removed: string[] }> {
  const stateRoot = defaultStateRoot();
  const removed: string[] = [];

  let files: string[];
  try {
    files = await readdir(stateRoot);
  } catch {
    // No state dir — no-op
    return { removed };
  }

  const jsonFiles = files.filter((f) => f.endsWith(".json"));
  if (jsonFiles.length === 0) {
    return { removed };
  }

  // Health check: if herdr is down, exit 6 (fail safe — keep all files)
  const health = await exec("herdr", ["workspace", "list"], { timeout: 10_000 });
  if (health.code !== 0) {
    throw new ExecError("herdr", health.code, health.stdout, health.stderr, false, false);
  }

  for (const file of jsonFiles) {
    const key = file.replace(/\.json$/, "");
    const filePath = join(stateRoot, file);

    let content: string;
    try {
      content = await readFile(filePath, "utf8");
    } catch {
      continue; // File disappeared
    }

    let parsed: unknown;
    try {
      parsed = JSON.parse(content);
    } catch {
      // Corrupt JSON — back up, keep it (unparseable targets mean kept)
      await writeFile(`${filePath}.bak`, content).catch(() => {});
      continue;
    }

    if (!isReviewBoxManifest(parsed)) {
      // Valid JSON but wrong schema — back up, keep it
      await writeFile(`${filePath}.bak`, content).catch(() => {});
      continue;
    }

    const manifest = parsed as ReviewBoxManifest;

    // Check if workspace is gone (herdr workspace get)
    let workspaceGone = false;
    const wsResult = await exec("herdr", ["workspace", "get", manifest.workspaceId], {
      timeout: 10_000,
    });
    workspaceGone = wsResult.code !== 0;

    // Check if worktree dir is gone (filesystem)
    let worktreeGone = false;
    try {
      await stat(manifest.worktreePath);
    } catch {
      worktreeGone = true;
    }

    if (workspaceGone && worktreeGone) {
      await unlink(filePath).catch(() => {});
      removed.push(key);
    }
  }

  return { removed };
}
