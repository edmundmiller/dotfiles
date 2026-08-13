import { describe, expect, test, afterEach } from "bun:test";
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

let env: Env | null = null;
afterEach(() => {
  if (env) {
    env.cleanup();
    env = null;
  }
});

describe("config discovery (VAL-BRIDGE-013, 026, 031, 038)", () => {
  test("unmapped repository exits 5", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({ ...JSON.parse(STD_PR_JSON), repository: "unknown/repo" });
    const result = await runCli(env, { stdin: payload });
    expect(result.exitCode).toBe(5);
    expect(result.stdout).toContain('"error"');
    expect(result.stderr).toContain("repo root");
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(false);
  });

  test("config file absent exits 5 for any repository", async () => {
    // Create env without any config mapping
    env = setupEnv({});
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(5);
    expect(result.stdout).toContain('"error"');
  });

  test("REVIEW_BOX_REPO_ROOT is ignored (R7) — valid config present", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, {
      stdin: STD_PR_JSON,
      extraEnv: { REVIEW_BOX_REPO_ROOT: "/nonexistent/bogus/path" },
    });
    expect(result.exitCode).toBe(0);
    const out = JSON.parse(result.stdout);
    expect(out.status).toBe("created");
    const manifest = JSON.parse(await Bun.file(`${env.stateDir}/${STD_MANIFEST_KEY}.json`).text());
    // repoRoot should be the config value, not the env var
    expect(manifest.repoRoot).toBe(env.repoRoot);
  });

  test("REVIEW_BOX_REPO_ROOT does not rescue unmapped repo (R7)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({ ...JSON.parse(STD_PR_JSON), repository: "unknown/repo" });
    const result = await runCli(env, {
      stdin: payload,
      extraEnv: { REVIEW_BOX_REPO_ROOT: "/some/path" },
    });
    expect(result.exitCode).toBe(5);
  });

  test("malformed config.json exits 5", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    // Overwrite config with invalid JSON
    await Bun.write(`${env.configDir}/config.json`, "{ not valid json");
    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(5);
    expect(result.stdout).toContain('"error"');
    expect(result.stderr).toContain("config");
  });

  test("configured repoRoot missing on disk exits 5", async () => {
    env = setupEnv({});
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    // Write config mapping to a nonexistent path
    await Bun.write(
      `${env.configDir}/config.json`,
      JSON.stringify({ "edmundmiller/dotfiles": "/nonexistent/repo/path" })
    );
    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(5);
    expect(result.stderr).toContain("missing");
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(false);
  });

  test("XDG_CONFIG_HOME honored for config discovery (R8a)", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    // XDG_CONFIG_HOME is already set to env.configHome in runCli
    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(0);
    // Verify $HOME/.config/review-box was NOT created
    const homeConfig = `${env.home}/.config/review-box`;
    const { existsSync } = await import("node:fs");
    expect(existsSync(homeConfig)).toBe(false);
  });

  test("XDG_CONFIG_HOME precedence over ~/.config (R8c)", async () => {
    env = setupEnv({});
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    // Create XDG config with repoRoot X
    const { mkdirSync, realpathSync } = await import("node:fs");
    const xdgRepoRaw = `${env.home}/xdg-repo`;
    mkdirSync(xdgRepoRaw, { recursive: true });
    const xdgRepoRoot = realpathSync(xdgRepoRaw);
    await Bun.write(
      `${env.configDir}/config.json`,
      JSON.stringify({ "edmundmiller/dotfiles": xdgRepoRoot })
    );

    // Create ~/.config config with different repoRoot Y
    const homeConfigDir = `${env.home}/.config/review-box`;
    mkdirSync(homeConfigDir, { recursive: true });
    const homeRepoRoot = `${env.home}/home-repo`;
    mkdirSync(homeRepoRoot, { recursive: true });
    await Bun.write(
      `${homeConfigDir}/config.json`,
      JSON.stringify({ "edmundmiller/dotfiles": homeRepoRoot })
    );

    const result = await runCli(env, { stdin: STD_PR_JSON });
    expect(result.exitCode).toBe(0);
    const manifest = JSON.parse(await Bun.file(`${env.stateDir}/${STD_MANIFEST_KEY}.json`).text());
    // XDG config should win — repoRoot should be X, not Y
    expect(manifest.repoRoot).toBe(xdgRepoRoot);
  });

  test("fallback to ~/.config when XDG_CONFIG_HOME unset (R8b)", async () => {
    env = setupEnv({});
    setGhProfile(env, { pr: STD_GH_RESPONSE });

    // Set up ~/.config/review-box/config.json
    const { mkdirSync } = await import("node:fs");
    const homeConfigDir = `${env.home}/.config/review-box`;
    mkdirSync(homeConfigDir, { recursive: true });
    await Bun.write(
      `${homeConfigDir}/config.json`,
      JSON.stringify({ "edmundmiller/dotfiles": env.repoRoot })
    );

    const result = await runCli(env, {
      stdin: STD_PR_JSON,
      extraEnv: { XDG_CONFIG_HOME: "" },
    });
    expect(result.exitCode).toBe(0);
  });
});
