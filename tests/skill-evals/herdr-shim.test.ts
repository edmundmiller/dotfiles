import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

import { countHelpCalls } from "./herdr-skill-harness";

const shim = join(dirname(fileURLToPath(import.meta.url)), "herdr-shim.sh");
const corpus = join(dirname(fileURLToPath(import.meta.url)), "herdr-help-corpus.json");

function runShim(args: string[]) {
  const dir = mkdtempSync(join(tmpdir(), "herdr-shim-test-"));
  const log = join(dir, "calls.log");
  try {
    let status = 0;
    try {
      execFileSync(shim, args, {
        env: { ...process.env, HERDR_SHIM_LOG: log, HERDR_HELP_CORPUS: corpus },
        stdio: "pipe",
      });
    } catch (error) {
      status = (error as { status?: number }).status ?? 1;
    }
    return { status, log: readFileSync(log, "utf8") };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

describe("herdr shim", () => {
  it("allows help invocations", () => {
    for (const args of [["agent", "--help"], ["pane", "split", "--help"], ["--version"]]) {
      expect(runShim(args).status).toBe(0);
    }
  });

  it("refuses live queries that would leak session state or answers", () => {
    for (const args of [
      ["agent", "list"],
      ["pane", "list"],
      ["agent", "read", "w1:p1"],
    ]) {
      expect(runShim(args).status).toBe(64);
    }
  });

  it("refuses mutations against the live session", () => {
    for (const args of [
      ["agent", "start", "x", "--kind", "omp"],
      ["pane", "split", "--current"],
      ["pane", "close", "w1:p1"],
      ["agent", "prompt", "x", "go"],
    ]) {
      expect(runShim(args).status).toBe(64);
    }
  });

  it("records every attempt, including refused ones", () => {
    const { log } = runShim(["agent", "start", "x"]);
    expect(log.trim()).toBe("agent start x");
  });

  it("logs in a form countHelpCalls can score", () => {
    expect(countHelpCalls(runShim(["agent", "--help"]).log)).toBe(1);
    expect(countHelpCalls(runShim(["agent", "list"]).log)).toBe(0);
  });
});
