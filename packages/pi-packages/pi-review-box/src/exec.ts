/**
 * Exec function with timeout and ENOENT handling.
 *
 * Spawns child processes via node:child_process, captures stdout/stderr,
 * enforces timeouts (kills child with SIGKILL), and detects missing binaries
 * (ENOENT). Never prompts — stdin is always "ignore".
 */

import { spawn } from "node:child_process";

export class ExecError extends Error {
  constructor(
    public cmd: string,
    public exitCode: number,
    public stdout: string,
    public stderr: string,
    public timedOut: boolean,
    public enoent: boolean
  ) {
    super(
      enoent
        ? `command not found: ${cmd}`
        : timedOut
          ? `command timed out after ${exitCode}ms: ${cmd}`
          : `${cmd} failed with exit code ${exitCode}`
    );
    this.name = "ExecError";
  }
}

/**
 * Spawn a command, capture stdout/stderr, enforce a timeout.
 * Throws ExecError on ENOENT (binary not found) or timeout.
 * Returns {stdout, stderr, code} on normal completion (code may be non-zero).
 */
export async function exec(
  cmd: string,
  args: string[],
  opts?: { cwd?: string; timeout?: number }
): Promise<{ stdout: string; stderr: string; code: number }> {
  return new Promise((resolve, reject) => {
    // detached: true makes the child a process group leader so we can
    // kill the entire group (including sleep children) on timeout.
    const child = spawn(cmd, args, {
      cwd: opts?.cwd,
      stdio: ["ignore", "pipe", "pipe"],
      detached: true,
    });

    let stdout = "";
    let stderr = "";
    let timedOut = false;

    child.stdout?.on("data", (data: Buffer) => {
      stdout += data.toString();
    });
    child.stderr?.on("data", (data: Buffer) => {
      stderr += data.toString();
    });

    const timeout = opts?.timeout ?? 30_000;
    const timer = setTimeout(() => {
      timedOut = true;
      try {
        // Kill the entire process group (negative PID)
        process.kill(-child.pid!, "SIGKILL");
      } catch {
        try {
          child.kill("SIGKILL");
        } catch {
          // Process may have already exited
        }
      }
    }, timeout);

    child.on("error", (err: NodeJS.ErrnoException) => {
      clearTimeout(timer);
      if (err.code === "ENOENT") {
        reject(new ExecError(cmd, -1, stdout, stderr, false, true));
      } else {
        reject(new ExecError(cmd, -1, stdout, stderr, false, false));
      }
    });

    child.on("close", (code: number | null) => {
      clearTimeout(timer);
      if (timedOut) {
        reject(new ExecError(cmd, timeout, stdout, stderr, true, false));
      } else {
        resolve({ stdout, stderr, code: code ?? -1 });
      }
    });
  });
}
