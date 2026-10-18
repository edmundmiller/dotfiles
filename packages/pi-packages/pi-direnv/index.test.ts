import { afterEach, beforeEach, expect, test } from "bun:test";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import environmentExtension from "./index.js";

type Exec = ExtensionAPI["exec"];
type Handler = (
  event: unknown,
  ctx: {
    sessionManager: { getCwd(): string };
    ui: { notify(message: string): void };
  }
) => Promise<void>;

const exec: Exec = async (command, args, options) => {
  const child = Bun.spawn([command, ...args], {
    cwd: options?.cwd,
    stdin: "ignore",
    stdout: "pipe",
    stderr: "pipe",
  });
  const [stdout, stderr, code] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ]);
  return { stdout, stderr, code, killed: false };
};

function session(run: Exec = exec) {
  const handlers = new Map<string, Handler>();
  const notices: string[] = [];
  const api: Partial<ExtensionAPI> = {
    exec: run,
    on(name, handler) {
      // SAFETY: Only session events are registered; fixtures supply every field the loader reads.
      handlers.set(name, handler as Handler);
    },
  };
  // SAFETY: The loader uses only registration and exec on ExtensionAPI.
  environmentExtension(api as ExtensionAPI);
  return {
    notices,
    async open(cwd: string, event = "session_switch") {
      const handler = handlers.get(event);
      if (!handler) throw new Error(`Missing ${event}`);
      await handler(
        {},
        {
          sessionManager: { getCwd: () => cwd },
          ui: { notify: (message) => notices.push(message) },
        }
      );
    },
  };
}

let temp: string;
let baseline: NodeJS.ProcessEnv;
let launch: string;
beforeEach(() => {
  baseline = { ...process.env };
  launch = process.cwd();
  temp = mkdtempSync(join(tmpdir(), "pi-project-env-"));
  const emptyConfig = join(temp, "empty.toml");
  writeFileSync(emptyConfig, "");
  Object.assign(process.env, {
    MISE_DATA_DIR: join(temp, "data"),
    MISE_STATE_DIR: join(temp, "state"),
    MISE_CACHE_DIR: join(temp, "cache"),
    MISE_GLOBAL_CONFIG_FILE: emptyConfig,
    MISE_SYSTEM_CONFIG_FILE: emptyConfig,
  });
  delete process.env.MISE_TRUSTED_CONFIG_PATHS;
  delete process.env.__MISE_DIFF;
  process.chdir(temp);
});
afterEach(() => {
  process.chdir(launch);
  for (const key of Object.keys(process.env)) if (!(key in baseline)) delete process.env[key];
  Object.assign(process.env, baseline);
  rmSync(temp, { recursive: true, force: true });
});

function project(name: string, config?: [string, string]) {
  const root = join(temp, name);
  mkdirSync(join(root, "src"), { recursive: true });
  Bun.spawnSync(["git", "init", "--quiet", root]);
  if (config) writeFileSync(join(root, config[0]), config[1]);
  return root;
}

test.skipIf(!Bun.which("mise"))(
  "loads trusted mise environments by session cwd and restores them across switches",
  async () => {
    process.env.PI_ENV_SHARED = "original";
    const path = process.env.PATH;
    const a = project("a", [
      "mise.toml",
      '[env]\nPI_ENV_SHARED="a"\nPI_ENV_ONLY_A="yes"\n_.path=["bin"]\n',
    ]);
    const b = project("b", ["mise.toml", '[env]\nPI_ENV_SHARED="b"\nPI_ENV_ONLY_B="yes"\n']);
    const empty = project("empty");
    for (const root of [a, b]) {
      expect(
        (
          await exec("env", ["MISE_PARANOID=1", "mise", "trust", join(root, "mise.toml")], {
            cwd: root,
          })
        ).code
      ).toBe(0);
    }
    // A direnv file must not take precedence over mise or run automatically here.
    writeFileSync(join(a, ".envrc"), "exit 1\n");
    const loader = session();
    await loader.open(join(a, "src"), "session_start");
    expect(process.env.PI_ENV_SHARED).toBe("a");
    expect(process.env.PI_ENV_ONLY_A).toBe("yes");
    expect(process.env.PATH?.split(":")[0]).toBe(join(a, "bin"));
    await loader.open(b);
    expect(process.env.PI_ENV_SHARED).toBe("b");
    expect(process.env.PI_ENV_ONLY_A).toBeUndefined();
    expect(process.env.PI_ENV_ONLY_B).toBe("yes");
    expect(process.env.PATH?.split(":")).not.toContain(join(a, "bin"));
    await loader.open(empty);
    expect(process.env.PI_ENV_SHARED).toBe("original");
    expect(process.env.PI_ENV_ONLY_B).toBeUndefined();
    expect(process.env.PATH).toBe(path);
  }
);

test.skipIf(!Bun.which("mise"))(
  "does not trust configs, install tools, or run hooks during session loading",
  async () => {
    const marker = join(temp, "executed");
    const blocked = project("blocked", [
      "mise.toml",
      `[env]\nPI_ENV_BAD = "{{ exec(command='touch ${marker}') }}"\n`,
    ]);
    process.env.MISE_YES = "1";
    process.env.CI = "true";
    const loader = session();
    await loader.open(blocked);
    expect(existsSync(marker)).toBe(false);
    expect(process.env.PI_ENV_BAD).toBeUndefined();
    expect(loader.notices.some((notice) => notice.includes("not loaded"))).toBe(true);
    const trusted = project("trusted", [
      "mise.toml",
      `[env]\nPI_ENV_SAFE="loaded"\n[hooks]\npreinstall="touch ${marker}"\nenter="touch ${marker}"\n[tools]\nnode="22.0.0"\n`,
    ]);
    expect(
      (
        await exec("env", ["MISE_PARANOID=1", "mise", "trust", join(trusted, "mise.toml")], {
          cwd: trusted,
        })
      ).code
    ).toBe(0);
    await loader.open(trusted);
    expect(process.env.PI_ENV_SAFE).toBe("loaded");
    expect(existsSync(marker)).toBe(false);
    expect(existsSync(join(temp, "data", "installs", "node"))).toBe(false);
    expect(process.env.MISE_YES).toBe("1");
  }
);

test("direnv fallback removes null exports and restores values before failed or empty projects", async () => {
  process.env.PI_ENV_SHARED = "original";
  const a = project("a", [".envrc", ""]);
  const b = project("b", [".envrc", ""]);
  const empty = project("empty");
  // Parent config is outside the repository and must not load.
  writeFileSync(join(temp, ".envrc"), "");
  for (const failure of ["nonzero", "invalid", "missing"]) {
    const loader = session(async (command, args, options) => {
      if (command === "git") return exec(command, args, options);
      if (command !== "direnv") throw new Error("Unexpected provider");
      if (options?.cwd === join(a, "src"))
        return {
          stdout: JSON.stringify({ PI_ENV_SHARED: null, PI_ENV_ADDED: "yes" }),
          stderr: "",
          code: 0,
          killed: false,
        };
      if (options?.cwd === empty)
        return {
          stdout: '{"PI_ENV_BAD":"outside repository"}',
          stderr: "",
          code: 0,
          killed: false,
        };
      if (failure === "missing") throw new Error("ENOENT");
      return {
        stdout: failure === "invalid" ? '{"PI_ENV_BAD":42}' : '{"PI_ENV_BAD":"must not load"}',
        stderr: "secret",
        code: failure === "nonzero" ? 1 : 0,
        killed: false,
      };
    });
    await loader.open(join(a, "src"), "session_start");
    expect(process.env.PI_ENV_SHARED).toBeUndefined();
    expect(process.env.PI_ENV_ADDED).toBe("yes");
    await loader.open(b);
    expect(process.env.PI_ENV_SHARED).toBe("original");
    expect(process.env.PI_ENV_ADDED).toBeUndefined();
    expect(process.env.PI_ENV_BAD).toBeUndefined();
    await loader.open(empty);
    expect(process.env.PI_ENV_SHARED).toBe("original");
    expect(process.env.PI_ENV_BAD).toBeUndefined();
    expect(loader.notices.join("\n")).not.toContain("secret");
  }
});
