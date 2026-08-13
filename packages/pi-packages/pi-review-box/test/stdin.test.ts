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

describe("stdin contract (VAL-BRIDGE-006, 007, 008, 032)", () => {
  test("rejects non-JSON garbage with exit 2 and zero side effects", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, { stdin: "this is not json" });
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toContain('"error"');
    expect(readLog(env.ghLog)).toHaveLength(0);
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(false);
  });

  test("rejects empty stdin with exit 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, { stdin: "" });
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toContain('"error"');
    expect(readLog(env.ghLog)).toHaveLength(0);
  });

  test("rejects valid JSON array (non-object) with exit 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, { stdin: "[1, 2, 3]" });
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toContain('"error"');
    expect(readLog(env.ghLog)).toHaveLength(0);
  });

  test("rejects valid JSON string (non-object) with exit 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, { stdin: '"hello"' });
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toContain('"error"');
  });

  test("rejects valid JSON number (non-object) with exit 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, { stdin: "42" });
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toContain('"error"');
  });

  test("rejects trailing garbage after valid JSON object with exit 2 and zero side effects", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, { stdin: `${STD_PR_JSON} junk` });
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toContain('"error"');
    expect(readLog(env.ghLog)).toHaveLength(0);
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(false);
  });

  test("rejects trailing JSON object after valid JSON object", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const result = await runCli(env, { stdin: `${STD_PR_JSON}${STD_PR_JSON}` });
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toContain('"error"');
  });

  test("missing repository field exits 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({ ...JSON.parse(STD_PR_JSON), repository: undefined });
    const result = await runCli(env, { stdin: payload });
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toContain('"error"');
  });

  test("missing number field exits 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({ ...JSON.parse(STD_PR_JSON), number: undefined });
    const result = await runCli(env, { stdin: payload });
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toContain('"error"');
  });

  test("number as string exits 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({ ...JSON.parse(STD_PR_JSON), number: "216" });
    const result = await runCli(env, { stdin: payload });
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toContain('"error"');
  });

  test("repository not matching owner/name shape exits 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({ ...JSON.parse(STD_PR_JSON), repository: "just-a-name" });
    const result = await runCli(env, { stdin: payload });
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toContain('"error"');
  });

  test("repository with too many slashes exits 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({ ...JSON.parse(STD_PR_JSON), repository: "a/b/c" });
    const result = await runCli(env, { stdin: payload });
    expect(result.exitCode).toBe(2);
    expect(result.stdout).toContain('"error"');
  });

  test("number 0 exits 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({ ...JSON.parse(STD_PR_JSON), number: 0 });
    const result = await runCli(env, { stdin: payload });
    expect(result.exitCode).toBe(2);
  });

  test("number -1 exits 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({ ...JSON.parse(STD_PR_JSON), number: -1 });
    const result = await runCli(env, { stdin: payload });
    expect(result.exitCode).toBe(2);
  });

  test("number 1.5 exits 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({ ...JSON.parse(STD_PR_JSON), number: 1.5 });
    const result = await runCli(env, { stdin: payload });
    expect(result.exitCode).toBe(2);
  });

  test("null fields exit 2", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({ ...JSON.parse(STD_PR_JSON), title: null });
    const result = await runCli(env, { stdin: payload });
    expect(result.exitCode).toBe(2);
  });

  test("case-variant repository is accepted (R5)", async () => {
    env = setupEnv({ repo: "EdmundMiller/Dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({
      ...JSON.parse(STD_PR_JSON),
      repository: "EdmundMiller/Dotfiles",
    });
    const result = await runCli(env, { stdin: payload });
    expect(result.exitCode).toBe(0);
    const out = JSON.parse(result.stdout);
    expect(out.status).toBe("created");
    expect(manifestExists(env, STD_MANIFEST_KEY)).toBe(true);
  });

  test("unknown extra fields are tolerated", async () => {
    env = setupEnv({ repo: "edmundmiller/dotfiles" });
    setGhProfile(env, { pr: STD_GH_RESPONSE });
    const payload = JSON.stringify({ ...JSON.parse(STD_PR_JSON), extra: "x", future: 123 });
    const result = await runCli(env, { stdin: payload });
    expect(result.exitCode).toBe(0);
    const out = JSON.parse(result.stdout);
    expect(out.status).toBe("created");
    // Extra fields must not appear in manifest
    const manifest = JSON.parse(await Bun.file(`${env.stateDir}/${STD_MANIFEST_KEY}.json`).text());
    expect(manifest.extra).toBeUndefined();
    expect(manifest.future).toBeUndefined();
  });
});
