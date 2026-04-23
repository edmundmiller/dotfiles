/**
 * Tests for pi-dcp config loading and generation.
 */
import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from "fs";
import { tmpdir } from "os";
import { join } from "path";
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { generateConfigFileContent, loadConfig } from "../src/config";
import { registerRule } from "../src/registry";
import { recencyRule } from "../src/rules/recency";

function fakePi(flags: Record<string, unknown> = {}): ExtensionAPI {
  return {
    getFlag(name: string) {
      return flags[name];
    },
  } as unknown as ExtensionAPI;
}

function writeTsConfig(path: string, body: string): void {
  writeFileSync(path, `export default ${body};\n`, "utf8");
}

describe("config loading", () => {
  const originalCwd = process.cwd();
  const originalHome = process.env.HOME;
  const originalEnv = { ...process.env };
  let sandbox: string;

  beforeEach(() => {
    sandbox = mkdtempSync(join(tmpdir(), "pi-dcp-config-test-"));
    process.chdir(sandbox);
    process.env.HOME = join(sandbox, "home");
    mkdirSync(process.env.HOME, { recursive: true });
    registerRule(recencyRule);
  });

  afterEach(() => {
    process.chdir(originalCwd);
    for (const key of Object.keys(process.env)) {
      if (!(key in originalEnv)) {
        delete process.env[key];
      }
    }
    for (const [key, value] of Object.entries(originalEnv)) {
      process.env[key] = value;
    }
    if (originalHome === undefined) {
      delete process.env.HOME;
    } else {
      process.env.HOME = originalHome;
    }
    rmSync(sandbox, { recursive: true, force: true });
  });

  test("generateConfigFileContent returns valid content in both modes", () => {
    const full = generateConfigFileContent();
    const simplified = generateConfigFileContent({ simplified: true });

    expect(full).toContain("export default {");
    expect(full).toContain("keepRecentCount: 10");
    expect(simplified).toContain("export default {");
    expect(simplified).toContain("enabled: true");
  });

  test("loads dcp.config.ts from cwd", async () => {
    writeTsConfig(join(sandbox, "dcp.config.ts"), `{ keepRecentCount: 7 }`);

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(7);
    expect(config.turnProtection?.enabled).toBe(true);
  });

  test("loads .dcprc with module syntax", async () => {
    writeFileSync(join(sandbox, ".dcprc"), `export default { keepRecentCount: 8 };\n`, "utf8");

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(8);
  });

  test("loads .dcprc as JSON", async () => {
    writeFileSync(join(sandbox, ".dcprc"), JSON.stringify({ keepRecentCount: 9 }), "utf8");

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(9);
  });

  test("loads dcp.config.toml", async () => {
    writeFileSync(join(sandbox, "dcp.config.toml"), "keepRecentCount = 18\n", "utf8");

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(18);
  });

  test("loads dcp.config.yaml", async () => {
    writeFileSync(join(sandbox, "dcp.config.yaml"), "keepRecentCount: 19\n", "utf8");

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(19);
  });

  test("cwd config beats home config", async () => {
    writeTsConfig(join(sandbox, "dcp.config.ts"), `{ keepRecentCount: 11 }`);
    writeTsConfig(join(process.env.HOME!, "dcp.config.ts"), `{ keepRecentCount: 22 }`);

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(11);
  });

  test("home config is used when cwd has none", async () => {
    writeTsConfig(join(process.env.HOME!, "dcp.config.ts"), `{ keepRecentCount: 22 }`);

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(22);
  });

  test("home config merges with project config", async () => {
    writeTsConfig(
      join(process.env.HOME!, "dcp.config.ts"),
      `{ debug: true, turnProtection: { enabled: false, turns: 9 } }`
    );
    writeTsConfig(join(sandbox, "dcp.config.ts"), `{ keepRecentCount: 41 }`);

    const config = await loadConfig(fakePi());
    expect(config.debug).toBe(true);
    expect(config.keepRecentCount).toBe(41);
    expect(config.turnProtection?.enabled).toBe(false);
    expect(config.turnProtection?.turns).toBe(9);
  });

  test("module-style .dcprc preserves relative imports", async () => {
    writeFileSync(join(sandbox, "helper.ts"), `export default 27;\n`, "utf8");
    writeFileSync(
      join(sandbox, ".dcprc"),
      `import value from "./helper.ts";\nexport default { keepRecentCount: value };\n`,
      "utf8"
    );

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(27);
  });

  test("deep merge preserves nested defaults", async () => {
    writeTsConfig(join(sandbox, "dcp.config.ts"), `{ turnProtection: { turns: 5 } }`);

    const config = await loadConfig(fakePi());
    expect(config.turnProtection?.enabled).toBe(true);
    expect(config.turnProtection?.turns).toBe(5);
  });

  test("file config overrides env vars", async () => {
    process.env.PI_DCP_KEEP_RECENT_COUNT = "99";
    writeTsConfig(join(sandbox, "dcp.config.ts"), `{ keepRecentCount: 13 }`);

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(13);
  });

  test("env vars support booleans, numbers, arrays, and nested fields", async () => {
    process.env.PI_DCP_ENABLED = "0";
    process.env.PI_DCP_DEBUG = "1";
    process.env.PI_DCP_KEEP_RECENT_COUNT = "12";
    process.env.PI_DCP_RULES = '["recency"]';
    process.env.PI_DCP_TURN_PROTECTION_TURNS = "6";
    process.env.PI_DCP_TURN_PROTECTION_ENABLED = "false";
    process.env.PI_DCP_LOG_DIR = "/tmp/pi-dcp-test-logs";

    const config = await loadConfig(fakePi());
    expect(config.enabled).toBe(false);
    expect(config.debug).toBe(true);
    expect(config.keepRecentCount).toBe(12);
    expect(config.turnProtection?.turns).toBe(6);
    expect(config.turnProtection?.enabled).toBe(false);
    expect(config.logDir).toBe("/tmp/pi-dcp-test-logs");
    expect(config.rules.map((rule) => rule.name)).toEqual(["recency"]);
  });

  test("CLI flags override file and env values", async () => {
    process.env.PI_DCP_ENABLED = "false";
    process.env.PI_DCP_DEBUG = "false";
    writeTsConfig(join(sandbox, "dcp.config.ts"), `{ enabled: false, debug: false }`);

    const config = await loadConfig(fakePi({ "--dcp-enabled": true, "--dcp-debug": true }));
    expect(config.enabled).toBe(true);
    expect(config.debug).toBe(true);
  });

  test("package.json supports pi-dcp and dcp keys", async () => {
    writeFileSync(
      join(sandbox, "package.json"),
      JSON.stringify({ dcp: { keepRecentCount: 14 }, "pi-dcp": { keepRecentCount: 15 } }, null, 2),
      "utf8"
    );

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(15);
  });

  test("home config beats package.json", async () => {
    writeTsConfig(join(process.env.HOME!, "dcp.config.ts"), `{ keepRecentCount: 22 }`);
    writeFileSync(join(sandbox, "package.json"), JSON.stringify({ "pi-dcp": { keepRecentCount: 15 } }), "utf8");

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(22);
  });

  test("ignores malformed package.json", async () => {
    writeFileSync(join(sandbox, "package.json"), '{ invalid json', "utf8");

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(10);
  });

  test("supports compatibility filename pi-dcp.config.json", async () => {
    writeFileSync(join(sandbox, "pi-dcp.config.json"), JSON.stringify({ keepRecentCount: 16 }), "utf8");

    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(16);
  });

  test("ignores unrelated generic config.json files", async () => {
    writeFileSync(join(sandbox, "config.json"), JSON.stringify({ keepRecentCount: 17 }), "utf8");
    const config = await loadConfig(fakePi());
    expect(config.keepRecentCount).toBe(10);
  });
});
