import { execFileSync, spawnSync } from "node:child_process";
import {
  mkdtempSync,
  mkdirSync,
  copyFileSync,
  chmodSync,
  writeFileSync,
  readFileSync,
  realpathSync,
  rmSync,
} from "node:fs";
import { homedir, tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

import { describe, expect, it } from "vitest";

const shimPath = join(dirname(fileURLToPath(import.meta.url)), "herdr-shim.sh");
const corpusPath = join(dirname(fileURLToPath(import.meta.url)), "herdr-help-corpus.json");

// Non-throwing so this file still collects on a host without herdr.
const herdrInstalled =
  spawnSync("/bin/bash", ["-lc", "command -v herdr"], { stdio: "ignore" }).status === 0;

/**
 * Guards the bug that invalidated a whole sweep: Claude's Bash tool uses a
 * LOGIN shell, /etc/zprofile rebuilds PATH, and a PATH-only shim was silently
 * bypassed -- help calls went uncounted and the live session was unprotected.
 */
function loginShell(script: string) {
  const dir = mkdtempSync(join(tmpdir(), "herdr-intercept-"));
  const binDir = join(dir, "bin");
  const zdot = join(dir, "zdot");
  const log = join(dir, "log");
  mkdirSync(binDir);
  mkdirSync(zdot);
  const shimBin = join(binDir, "herdr");
  copyFileSync(shimPath, shimBin);
  chmodSync(shimBin, 0o755);
  writeFileSync(log, "");
  const rc = [
    `herdr() { command ${JSON.stringify(shimBin)} "$@"; }`,
    `export HERDR_SHIM_LOG=${JSON.stringify(log)}`,
    `export HERDR_HELP_CORPUS=${JSON.stringify(corpusPath)}`,
    "",
  ].join("\n");
  for (const f of [".zshenv", ".zprofile", ".zshrc"]) writeFileSync(join(zdot, f), rc);

  try {
    let status = 0;
    let stdout = "";
    try {
      stdout = execFileSync("/bin/zsh", ["-lc", script], {
        env: { ...process.env, ZDOTDIR: zdot, PATH: `${binDir}:${process.env.PATH ?? ""}` },
        encoding: "utf8",
        stdio: "pipe",
      });
    } catch (error) {
      const e = error as { status?: number; stdout?: string };
      status = e.status ?? 1;
      stdout = e.stdout ?? "";
    }
    return { status, stdout, log: readFileSync(log, "utf8") };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

describe("herdr interception under a login shell", () => {
  it("routes help through the shim even after the profile rebuilds PATH", () => {
    const { log } = loginShell("herdr agent --help >/dev/null 2>&1");
    expect(log.trim()).toBe("agent --help");
  });

  it("serves help from the captured corpus without executing the real herdr", () => {
    // HERDR_REAL_BIN is deliberately absent: if the shim ever regains a path
    // that execs the installed binary, this fails instead of quietly touching
    // the live session.
    const { stdout } = loginShell("herdr agent prompt --help 2>&1");
    expect(stdout).toContain("Submit a prompt to an agent");
  });

  it("fails loudly on an uncaptured help path instead of approximating one", () => {
    // An approximate reply could launder a hallucinated subcommand into
    // something that reads as supported.
    const { status, stdout } = loginShell("herdr agent bogus --help 2>&1");
    expect(status).toBe(66);
    expect(stdout).toContain("no captured help");
  });

  it("reproduces 0.8.0's rejection of `herdr help <path>`", () => {
    // There is no `help <subcommand>` form; the real CLI says "unknown
    // command: help". Resolving it to real help would invent a surface.
    const { stdout } = loginShell("herdr help agent prompt 2>&1");
    expect(stdout).toContain("unknown command: help");
  });

  it("refuses bare `herdr`, which launches a session rather than printing help", () => {
    const { status } = loginShell("herdr >/dev/null 2>&1");
    expect(status).toBe(64);
  });

  it("refuses live queries that a bypass would have allowed", () => {
    const { status, log } = loginShell("herdr pane list >/dev/null 2>&1");
    expect(status).toBe(64);
    expect(log.trim()).toBe("pane list");
  });

  it("refuses mutations under a login shell", () => {
    const { status, log } = loginShell("herdr agent prompt worker go >/dev/null 2>&1");
    expect(status).toBe(64);
    expect(log.trim()).toBe("agent prompt worker go");
  });

  it("fails closed when the audit log cannot be written", () => {
    const dir = mkdtempSync(join(tmpdir(), "herdr-intercept-ro-"));
    try {
      let status = 0;
      try {
        execFileSync(shimPath, ["agent", "--help"], {
          env: {
            ...process.env,
            HERDR_SHIM_LOG: join(dir, "nonexistent-dir", "log"),
            HERDR_HELP_CORPUS: corpusPath,
          },
          stdio: "pipe",
        });
      } catch (error) {
        status = (error as { status?: number }).status ?? 1;
      }
      // Must refuse, not run unrecorded.
      expect(status).not.toBe(0);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

/**
 * Name-based interception (PATH entry, shell function) is defeated by an
 * absolute path: `/etc/profiles/.../herdr pane list` was verified to reach the
 * live session and dump real pane data. Denying the IPC socket is what closes
 * that hole, and it holds regardless of which binary is used.
 */
describe("socket denial blocks routes around the shim", () => {
  // Lazy: at collection time this would run on every platform, so a host
  // without herdr fails to collect instead of skipping.
  function realBins() {
    const bin = execFileSync("/bin/bash", ["-lc", "command -v herdr"], {
      encoding: "utf8",
    }).trim();
    return { bin, resolved: realpathSync(bin) };
  }
  const runtimeDir = join(homedir(), ".config", "herdr");

  function sandboxed(script: string) {
    const dir = mkdtempSync(join(tmpdir(), "herdr-sockdeny-"));
    const policy = join(dir, "p.sb");
    writeFileSync(
      policy,
      [
        "(version 1)",
        "(allow default)",
        `(deny network* (subpath ${JSON.stringify(runtimeDir)}))`,
        `(deny file-read* file-write* (subpath ${JSON.stringify(runtimeDir)}))`,
        "",
      ].join("\n")
    );
    try {
      let status = 0;
      let stdout = "";
      try {
        stdout = execFileSync("sandbox-exec", ["-f", policy, "/bin/zsh", "-lc", script], {
          cwd: dir,
          encoding: "utf8",
          stdio: "pipe",
        });
      } catch (error) {
        const e = error as { status?: number; stdout?: string; stderr?: string };
        status = e.status ?? 1;
        stdout = `${e.stdout ?? ""}${e.stderr ?? ""}`;
      }
      return { status, stdout };
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }

  // Asserting only "nonzero" would also pass for a typo'd path or a failed
  // launch, proving nothing. Each case checks the denial reason, and that no
  // live pane data came back.
  const denied = /Operation not permitted|PermissionDenied/;

  const canRun = process.platform === "darwin" && herdrInstalled;

  it.runIf(canRun)("blocks the absolute installed path", () => {
    const { status, stdout } = sandboxed(`${JSON.stringify(realBins().bin)} pane list`);
    expect(status).not.toBe(0);
    expect(stdout).toMatch(denied);
    expect(stdout).not.toContain("pane_id");
  });

  it.runIf(canRun)("blocks the resolved store path", () => {
    const { status, stdout } = sandboxed(`${JSON.stringify(realBins().resolved)} pane list`);
    expect(status).not.toBe(0);
    expect(stdout).toMatch(denied);
    expect(stdout).not.toContain("pane_id");
  });

  it.runIf(canRun)("blocks a copy of the binary", () => {
    // `echo COPIED` proves the copy succeeded and ran, so a failed `cp` cannot
    // masquerade as a successful denial.
    const { status, stdout } = sandboxed(
      `cp ${JSON.stringify(realBins().resolved)} ./evil && echo COPIED && ./evil pane list`
    );
    expect(stdout).toContain("COPIED");
    expect(status).not.toBe(0);
    expect(stdout).toMatch(denied);
    expect(stdout).not.toContain("pane_id");
  });
});
