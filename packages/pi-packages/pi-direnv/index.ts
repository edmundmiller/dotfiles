import type {
  ExtensionAPI,
  ExtensionContext,
  SessionStartEvent,
  SessionSwitchEvent,
} from "@mariozechner/pi-coding-agent";
import { existsSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";

export default function (pi: ExtensionAPI) {
  const previous = new Map<string, string | undefined>();

  async function loadEnvironment(ctx: ExtensionContext, cwd: string) {
    // Undo only this extension's changes, including PATH, before resolving the
    // next project. An empty, unavailable, or untrusted project must not retain them.
    for (const [key, value] of previous) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    previous.clear();

    try {
      const gitRoot = await findGitRoot(pi, cwd);
      const provider = findEnvironment(cwd, gitRoot);
      if (!provider) return;
      // exec honors the no-install settings even on mise 2026.7.5. A JSON dump
      // avoids evaluating shell output. Never run project tasks or a Nix shell.
      const result =
        provider === "mise"
          ? await pi.exec(
              "env",
              [
                "MISE_YES=0",
                "MISE_PARANOID=1",
                "MISE_AUTO_INSTALL=0",
                "MISE_EXEC_AUTO_INSTALL=0",
                "MISE_NO_HOOKS=1",
                "mise",
                "exec",
                "--",
                "node",
                "-e",
                "process.stdout.write(JSON.stringify(process.env))",
              ],
              { cwd, timeout: 15000 }
            )
          : await pi.exec("direnv", ["export", "json"], { cwd, timeout: 15000 });
      if (result.code !== 0 || result.killed) {
        ctx.ui.notify(
          `${provider}: environment not loaded. Check ${provider === "mise" ? "mise trust" : "direnv allow"} in the session project.`,
          "warning"
        );
        return;
      }
      if (!result.stdout.trim()) return;
      const values: unknown = JSON.parse(result.stdout);
      // This is the subprocess JSON boundary: accept only a flat string/null record.
      // oxlint-disable-next-line anti-slop/no-runtime-typeof
      if (!values || typeof values !== "object" || Array.isArray(values)) return;
      const entries = Object.entries(values);
      // oxlint-disable-next-line anti-slop/no-runtime-typeof
      if (entries.some(([, value]) => typeof value !== "string" && value !== null)) return;
      // mise returns a complete child environment; direnv returns a delta.
      const changes = new Map<string, string | null>(entries);
      if (provider === "mise") {
        for (const key of Object.keys(process.env)) {
          if (!changes.has(key)) changes.set(key, null);
        }
        // These controls belong to the loader, not the interactive environment.
        for (const key of [
          "MISE_YES",
          "MISE_PARANOID",
          "MISE_AUTO_INSTALL",
          "MISE_EXEC_AUTO_INSTALL",
          "MISE_NO_HOOKS",
        ])
          changes.delete(key);
      }
      for (const [key, value] of changes) {
        if (process.env[key] === (value ?? undefined)) continue;
        previous.set(key, process.env[key]);
        if (value === null) delete process.env[key];
        else process.env[key] = value;
      }
      ctx.ui.notify(`${provider}: loaded project environment`, "info");
    } catch {
      // Missing tools and malformed output must not leave partial exports or
      // print environment values, which can contain secrets.
      ctx.ui.notify("Project environment unavailable", "warning");
    }
  }

  let pending = Promise.resolve();
  function load(_event: SessionStartEvent | SessionSwitchEvent, ctx: ExtensionContext) {
    const cwd = ctx.sessionManager.getCwd();
    pending = pending.then(() => loadEnvironment(ctx, cwd));
    return pending;
  }
  pi.on("session_start", load);
  pi.on("session_switch", load);
}

async function findGitRoot(pi: ExtensionAPI, cwd: string): Promise<string | null> {
  try {
    const result = await pi.exec("git", ["rev-parse", "--show-toplevel"], { cwd });
    return result.code === 0 ? result.stdout?.trim() || null : null;
  } catch {
    return null;
  }
}

function findEnvironment(startDir: string, stopAt: string | null): "mise" | "direnv" | null {
  const boundary = stopAt || "/";
  let current = startDir;
  let direnv = false;

  while (true) {
    if (
      readdirSync(current).some((name) => /^\.?mise(?:\..+)?\.toml$/.test(name)) ||
      existsSync(join(current, ".config/mise")) ||
      existsSync(join(current, ".mise"))
    )
      return "mise";
    direnv ||= existsSync(join(current, ".envrc"));

    if (current === boundary || current === "/") break;

    const parent = dirname(current);
    if (parent === current) break; // filesystem root
    current = parent;
  }

  return direnv ? "direnv" : null;
}
