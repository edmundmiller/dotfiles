import { describe, expect, test, afterEach } from "bun:test";
import { spawn } from "node:child_process";
import { join, dirname } from "node:path";
import {
  setupEnv,
  runCli,
  setGhProfile,
  readLog,
  STD_PR_JSON,
  STD_GH_RESPONSE,
  STD_MANIFEST_KEY,
  manifestExists,
  type Env,
} from "./helpers.js";

const CLI_PATH = join(dirname(dirname(import.meta.dir)), "pi-review-box", "src", "cli.ts");

let env: Env | null = null;
afterEach(() => {
  if (env) {
    env.cleanup();
    env = null;
  }
});

describe("interface (VAL-BRIDGE-032, 033, 034)", () => {
  test("--help prints usage to stdout exit 0 with zero side effects", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, { args: ["--help"] });
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("usage");
    expect(result.stdout).toContain("prune");
    expect(result.stdout).toContain("exit");
    expect(readLog(env.ghLog)).toHaveLength(0);
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(false);
  });

  test("-h prints usage to stdout exit 0", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    const result = await runCli(env, { args: ["-h"] });
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain("usage");
  });

  test("unknown subcommand exits 2 with usage on stderr", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, { args: ["frobnicate"] });
    expect(result.exitCode).toBe(2);
    expect(result.stderr).toContain("usage");
    expect(readLog(env.ghLog)).toHaveLength(0);
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(false);
  });

  test("TTY stdin exits 2 in under 5 seconds (VAL-BRIDGE-032)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    const path = [env.stubDir, process.env.PATH ?? ""].join(":");
    const fullEnv: Record<string, string> = {
      ...process.env,
      PATH: path,
      HOME: env.home,
      XDG_STATE_HOME: env.stateHome,
      XDG_CONFIG_HOME: env.configHome,
    };

    // Use python3 to create a PTY, run the CLI in it, and propagate exit code
    const pyScript = [
      "import pty, os, sys, json",
      `env = ${JSON.stringify(fullEnv)}`,
      `cli = ${JSON.stringify(CLI_PATH)}`,
      "pid, fd = pty.fork()",
      "if pid == 0:",
      "    os.execvpe('bun', ['bun', 'run', cli], env)",
      "else:",
      "    out = b''",
      "    try:",
      "        while True:",
      "            d = os.read(fd, 4096)",
      "            if not d: break",
      "            out += d",
      "    except OSError: pass",
      "    _, st = os.waitpid(pid, 0)",
      "    sys.stdout.buffer.write(out)",
      "    sys.exit(os.WEXITSTATUS(st) if os.WIFEXITED(st) else 1)",
    ].join("\n");

    const result = await new Promise<{ stdout: string; exitCode: number }>((resolve) => {
      const child = spawn("python3", ["-c", pyScript], {
        cwd: env.repoRoot,
        stdio: "pipe",
      });
      let stdout = "";
      child.stdout?.on("data", (d) => {
        stdout += d.toString();
      });
      child.on("close", (code) => resolve({ stdout, exitCode: code ?? -1 }));
      child.on("error", () => resolve({ stdout, exitCode: -1 }));
    });

    expect(result.exitCode).toBe(2);
    expect(result.stdout.toLowerCase()).toContain("usage");
  }, 10_000);
});
