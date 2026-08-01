import { execFileSync, spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const corpusPath = join(dirname(fileURLToPath(import.meta.url)), "herdr-help-corpus.json");
const corpus = JSON.parse(readFileSync(corpusPath, "utf8")) as Record<
  string,
  { stdout: string; exit: number }
>;

// Non-throwing: `execFileSync` at module scope would break collection on a
// host without herdr, which is exactly the case this guard exists for.
const herdrInstalled =
  spawnSync("/bin/bash", ["-lc", "command -v herdr"], { stdio: "ignore" }).status === 0;

/**
 * The corpus is a fixture pinned to a herdr version: the evals replay help from
 * it rather than executing herdr, so the sandbox can deny the IPC socket. That
 * only stays honest while the capture matches what is installed. Regenerate
 * with ./capture-herdr-help.py after a herdr upgrade.
 */
describe("herdr help corpus", () => {
  // Gate on herdr actually being installed, not on the platform: the corpus
  // ships in-repo and this file must collect cleanly on a host without it.
  it.runIf(herdrInstalled)("matches the installed herdr version", () => {
    const installed = execFileSync("/bin/bash", ["-lc", "herdr --version"], {
      encoding: "utf8",
    }).trim();
    expect(corpus["--version"].stdout.trim()).toBe(installed);
  });

  it("covers the subcommand groups the skill documents", () => {
    for (const key of [
      "agent start --help",
      "agent prompt --help",
      "agent wait --help",
      "pane split --help",
      "pane wait-output --help",
      "workspace create --help",
    ]) {
      expect(corpus, `missing corpus entry: ${key}`).toHaveProperty([key]);
    }
  });
});
