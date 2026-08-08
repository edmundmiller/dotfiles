// Materialize a git ref's tree into a temporary directory so the analyzer can
// index a past revision the same way it indexes the working tree.
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

export function repoRoot(cwd: string): string {
  const res = spawnSync("git", ["rev-parse", "--show-toplevel"], {
    cwd,
    encoding: "utf8",
  });
  if (res.status !== 0) throw new Error(`not a git repository: ${cwd}\n${res.stderr}`);
  return res.stdout.trim();
}

// Extract `ref` into a fresh temp dir via `git archive` and return its path.
export function materializeRef(ref: string, root: string): string {
  const dir = mkdtempSync(join(tmpdir(), "csd-"));
  const archive = spawnSync("git", ["archive", "--format=tar", ref], {
    cwd: root,
    encoding: "buffer",
    maxBuffer: 1024 * 1024 * 512,
  });
  if (archive.status !== 0)
    throw new Error(`git archive ${ref} failed: ${archive.stderr?.toString?.() ?? ""}`);
  const extract = spawnSync("tar", ["-x", "-C", dir], {
    input: archive.stdout,
  });
  if (extract.status !== 0) throw new Error(`tar extract failed for ref ${ref}`);
  return dir;
}
