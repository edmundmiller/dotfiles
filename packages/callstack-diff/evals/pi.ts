import { spawn } from "node:child_process";

export interface PiOptions {
  readonly extension?: string;
  readonly provider?: string;
  readonly model?: string;
}

export function buildPiArguments(prompt: string, options: PiOptions = {}): string[] {
  const args = [
    "--print",
    "--mode",
    "text",
    "--no-session",
    "--no-extensions",
    "--no-skills",
    "--no-prompt-templates",
    "--no-themes",
    "--no-context-files",
    "--tools",
    options.extension ? "read,callstack_diff" : "read",
  ];

  if (options.extension) args.push("--extension", options.extension);
  if (options.provider) args.push("--provider", options.provider);
  if (options.model) args.push("--model", options.model);
  args.push(prompt);
  return args;
}

function timeoutMilliseconds(): number {
  const seconds = Number(process.env.CALLSTACK_DIFF_EVAL_TIMEOUT ?? "150");
  if (!Number.isFinite(seconds) || seconds <= 0) {
    throw new Error("CALLSTACK_DIFF_EVAL_TIMEOUT must be a positive number of seconds");
  }
  return seconds * 1_000;
}

export function runPlainPi(
  prompt: string,
  cwd: string,
  signal?: AbortSignal,
  environment: Readonly<Record<string, string>> = {},
  extension?: string
): Promise<string> {
  const command = process.env.CALLSTACK_DIFF_EVAL_PI_BIN ?? "pi";
  const args = buildPiArguments(prompt, {
    extension,
    provider: process.env.CALLSTACK_DIFF_EVAL_PROVIDER,
    model: process.env.CALLSTACK_DIFF_EVAL_MODEL,
  });

  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      cwd,
      env: { ...process.env, ...environment, CI: "1", NO_COLOR: "1" },
      stdio: ["ignore", "pipe", "pipe"],
    });
    const stdout: Buffer[] = [];
    const stderr: Buffer[] = [];
    let timedOut = false;
    const abort = () => child.kill("SIGTERM");
    const timeout = setTimeout(() => {
      timedOut = true;
      child.kill("SIGTERM");
    }, timeoutMilliseconds());

    signal?.addEventListener("abort", abort, { once: true });
    child.stdout.on("data", (chunk: Buffer) => stdout.push(chunk));
    child.stderr.on("data", (chunk: Buffer) => stderr.push(chunk));
    child.on("error", (error) => {
      clearTimeout(timeout);
      signal?.removeEventListener("abort", abort);
      reject(error);
    });
    child.on("close", (code) => {
      clearTimeout(timeout);
      signal?.removeEventListener("abort", abort);
      const errorOutput = Buffer.concat(stderr).toString("utf8").trim();
      if (timedOut) {
        reject(new Error(`${command} exceeded CALLSTACK_DIFF_EVAL_TIMEOUT`));
      } else if (signal?.aborted) {
        reject(new Error(`${command} eval was aborted`));
      } else if (code === 0) {
        resolve(Buffer.concat(stdout).toString("utf8").trim());
      } else {
        reject(new Error(`${command} exited ${code ?? "without a code"}: ${errorOutput}`));
      }
    });
  });
}
