/**
 * pi-direnv Extension
 *
 * Automatically loads direnv environment variables at session start.
 * Ensures bash commands have access to project-specific env vars
 * defined in .envrc files (commonly used with Nix flakes).
 *
 * Behavior:
 * - Searches for .envrc from cwd up to git root
 * - Runs `direnv export json` and applies vars to process.env
 * - Shows notification if .envrc is blocked or env loaded
 * - Silently skips if direnv missing or no .envrc exists
 *
 * Inspired by https://github.com/simonwjackson/opencode-direnv
 */

import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    const cwd = process.cwd();

    // Check direnv is available
    try {
      await pi.exec("which", ["direnv"]);
    } catch {
      return; // direnv not installed, skip silently
    }

    // Find .envrc searching upward to git root
    const gitRoot = await findGitRoot(pi);
    const envrcPath = findEnvrc(cwd, gitRoot);
    if (!envrcPath) return;

    const envrcDir = dirname(envrcPath);

    try {
      const result = await pi.exec("direnv", ["export", "json"], { cwd: envrcDir });
      const output = result.stdout?.trim();
      if (!output) return;

      const envVars = JSON.parse(output) as Record<string, string>;
      const count = Object.keys(envVars).length;

      // Apply to process.env so child processes inherit them
      Object.assign(process.env, envVars);

      ctx.ui.notify(`direnv: loaded ${count} env vars`, "info");
    } catch (err: unknown) {
      const stderr =
        err && typeof err === "object" && "stderr" in err
          ? String((err as { stderr: unknown }).stderr)
          : "";

      if (stderr.includes("is blocked")) {
        ctx.ui.notify("direnv: .envrc is blocked. Run `direnv allow` to enable.", "warning");
      }
      // Other errors (parse failures, etc.) — skip silently
    }
  });
}

async function findGitRoot(pi: ExtensionAPI): Promise<string | null> {
  try {
    const result = await pi.exec("git", ["rev-parse", "--show-toplevel"]);
    return result.stdout?.trim() || null;
  } catch {
    return null;
  }
}

function findEnvrc(startDir: string, stopAt: string | null): string | null {
  const boundary = stopAt || "/";
  let current = startDir;

  while (true) {
    const envrcPath = join(current, ".envrc");
    if (existsSync(envrcPath)) return envrcPath;

    if (current === boundary || current === "/") break;

    const parent = dirname(current);
    if (parent === current) break; // filesystem root
    current = parent;
  }

  return null;
}
