/**
 * Configuration management for pi-dcp.
 *
 * Search precedence (highest to lowest):
 * 1. CLI flags (--dcp-enabled, --dcp-debug)
 * 2. First matching project config file
 * 3. First matching home config file
 * 4. package.json["pi-dcp"] or package.json["dcp"] in cwd
 * 5. Environment variables (PI_DCP_*)
 * 6. Default configuration
 */
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import {
  DcpConfigWithPruneRuleObjects,
  DcpConfigWithRuleRefs,
  PruneRule,
  isPruneRuleObject,
  type DcpConfig,
} from "./types";
import { getRule, getRuleNames } from "./registry";
import { getLogger } from "./logger";
import { existsSync, readFileSync } from "fs";
import { readFile, rm, writeFile } from "fs/promises";
import { homedir } from "os";
import { dirname, join } from "path";
import { pathToFileURL } from "url";

const MODULE_EXTENSIONS = [".ts", ".js", ".mjs", ".cjs", ".mts", ".cts"] as const;
const JSON_EXTENSIONS = [".json"] as const;
const TOML_EXTENSIONS = [".toml"] as const;
const YAML_EXTENSIONS = [".yaml", ".yml"] as const;

interface ConfigCandidate {
  path: string;
  kind: "module" | "json" | "toml" | "yaml" | "rc" | "package-json";
}

/**
 * Default configuration.
 */
const DEFAULT_CONFIG: DcpConfigWithRuleRefs = {
  enabled: true,
  debug: false,
  rules: ["deduplication", "superseded-writes", "error-purging", "tool-pairing", "recency"],
  keepRecentCount: 10,
  turnProtection: { enabled: true, turns: 3 },
  logDir: undefined,
};

function getHomeDir(): string {
  return process.env.HOME || homedir();
}

/**
 * Deep-merge source into target, returning a new object.
 * Arrays are replaced wholesale (not concatenated).
 */
function deepMerge<T extends Record<string, any>>(target: T, source: Partial<T>): T {
  const result = { ...target };

  for (const key of Object.keys(source) as (keyof T)[]) {
    const sourceValue = source[key];
    const targetValue = result[key];

    if (
      sourceValue !== null &&
      typeof sourceValue === "object" &&
      !Array.isArray(sourceValue) &&
      targetValue !== null &&
      typeof targetValue === "object" &&
      !Array.isArray(targetValue)
    ) {
      result[key] = deepMerge(targetValue as Record<string, any>, sourceValue as Record<string, any>) as T[keyof T];
    } else if (sourceValue !== undefined) {
      result[key] = sourceValue as T[keyof T];
    }
  }

  return result;
}

function formatEnvKey(key: string): string {
  return key.replace(/([A-Z])/g, "_$1").toUpperCase();
}

function parseBoolean(value: string): boolean {
  const normalized = value.trim().toLowerCase();
  if (["1", "true", "yes", "on"].includes(normalized)) return true;
  if (["0", "false", "no", "off"].includes(normalized)) return false;
  throw new Error(`invalid boolean: ${value}`);
}

function parseEnvValue(raw: string, sample: unknown): unknown {
  if (Array.isArray(sample)) {
    try {
      const parsed = JSON.parse(raw);
      if (Array.isArray(parsed)) return parsed;
    } catch {
      // Fall through to comma-separated parsing.
    }
    return raw
      .split(",")
      .map((part) => part.trim())
      .filter(Boolean);
  }

  if (typeof sample === "boolean") {
    return parseBoolean(raw);
  }

  if (typeof sample === "number") {
    const parsed = Number(raw);
    if (Number.isNaN(parsed)) {
      throw new Error(`invalid number: ${raw}`);
    }
    return parsed;
  }

  if (typeof sample === "string") {
    return raw;
  }

  if (sample !== null && typeof sample === "object") {
    return JSON.parse(raw);
  }

  return raw;
}

function getEnvOverride(path: string[]): string | undefined {
  const prefix = "PI_DCP";
  const camelKey = `${prefix}_${path.map(formatEnvKey).join("_")}`;
  const legacyKey = `${prefix}_${path.map((segment) => segment.toUpperCase()).join("_")}`;
  return process.env[camelKey] ?? process.env[legacyKey];
}

function applyEnvOverrides<T extends Record<string, any>>(config: T, path: string[] = []): T {
  const result = { ...config };

  for (const key of Object.keys(result) as (keyof T)[]) {
    const value = result[key];
    const envPath = [...path, String(key)];
    const envOverride = getEnvOverride(envPath);

    if (value !== null && typeof value === "object" && !Array.isArray(value)) {
      result[key] = applyEnvOverrides(value as Record<string, any>, envPath) as T[keyof T];
      continue;
    }

    if (envOverride !== undefined) {
      result[key] = parseEnvValue(envOverride, value) as T[keyof T];
    }
  }

  return result;
}

function createDirCandidates(dir: string): ConfigCandidate[] {
  const candidates: ConfigCandidate[] = [];
  const moduleBases = [
    "dcp.config",
    ".dcprc",
    ".dcprc.config",
    "pi-dcp.config",
    ".pi-dcp.config",
    "pi-dcp",
    ".pi-dcp",
  ];
  const jsonBases = [
    "dcp.config",
    ".dcprc",
    "pi-dcp.config",
    ".pi-dcp.config",
    "pi-dcp",
    ".pi-dcp",
  ];
  const tomlBases = jsonBases;
  const yamlBases = jsonBases;
  for (const base of moduleBases) {
    for (const ext of MODULE_EXTENSIONS) {
      candidates.push({ path: join(dir, `${base}${ext}`), kind: "module" });
    }
  }

  candidates.push({ path: join(dir, ".dcprc"), kind: "rc" });
  for (const base of jsonBases) {
    for (const ext of JSON_EXTENSIONS) {
      candidates.push({ path: join(dir, `${base}${ext}`), kind: "json" });
    }
  }

  for (const base of tomlBases) {
    for (const ext of TOML_EXTENSIONS) {
      candidates.push({ path: join(dir, `${base}${ext}`), kind: "toml" });
    }
  }

  for (const base of yamlBases) {
    for (const ext of YAML_EXTENSIONS) {
      candidates.push({ path: join(dir, `${base}${ext}`), kind: "yaml" });
    }
  }
  return candidates;
}

function createProjectCandidates(cwd: string): ConfigCandidate[] {
  const projectDirs = [cwd, join(cwd, "config"), join(cwd, ".config")];
  return projectDirs.flatMap(createDirCandidates);
}

function createHomeCandidates(home: string): ConfigCandidate[] {
  const homeDirs = [join(home, ".config", "pi-dcp"), join(home, ".config"), home];
  return homeDirs.flatMap(createDirCandidates);
}

async function importModuleConfig(path: string): Promise<unknown> {
  const imported = await import(pathToFileURL(path).href);
  return imported.default ?? imported;
}

async function loadRcConfig(path: string): Promise<unknown> {
  const source = await readFile(path, "utf-8");
  try {
    return JSON.parse(source);
  } catch {
    // Fall through and try loading as TS/JS module content.
  }

  const tempPath = join(dirname(path), `.pi-dcp-rc-loader-${process.pid}-${Date.now()}.ts`);

  try {
    await writeFile(tempPath, source, "utf-8");
    const imported = await import(pathToFileURL(tempPath).href);
    return imported.default ?? imported;
  } finally {
    await rm(tempPath, { force: true });
  }
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

async function loadCandidate(candidate: ConfigCandidate): Promise<DcpConfigWithRuleRefs | null> {
  if (!existsSync(candidate.path)) {
    return null;
  }

  let loaded: unknown;

  switch (candidate.kind) {
    case "module":
      loaded = await importModuleConfig(candidate.path);
      break;
    case "json":
      loaded = JSON.parse(readFileSync(candidate.path, "utf-8"));
      break;
    case "toml":
      loaded = Bun.TOML.parse(readFileSync(candidate.path, "utf-8"));
      break;
    case "yaml":
      loaded = Bun.YAML.parse(readFileSync(candidate.path, "utf-8"));
      break;
    case "rc":
      loaded = await loadRcConfig(candidate.path);
      break;
    case "package-json": {
      const pkg = JSON.parse(readFileSync(candidate.path, "utf-8"));
      loaded = pkg["pi-dcp"] ?? pkg["dcp"];
      break;
    }
  }

  if (loaded == null) {
    return null;
  }

  if (!isPlainObject(loaded)) {
    throw new Error(`config at ${candidate.path} must export an object`);
  }

  return loaded as DcpConfigWithRuleRefs;
}

async function loadFirstFromCandidates(candidates: ConfigCandidate[]): Promise<DcpConfigWithRuleRefs | null> {
  const logger = getLogger();
  for (const candidate of candidates) {
    try {
      const loaded = await loadCandidate(candidate);
      if (loaded) {
        return loaded;
      }
    } catch (error) {
      logger.warn(`pi-dcp: failed to load config from ${candidate.path}: ${error}`);
    }
  }
  return null;
}
async function loadConfigFromFiles(): Promise<DcpConfigWithRuleRefs> {
  const cwd = process.cwd();
  const home = getHomeDir();
  const withEnv = applyEnvOverrides(DEFAULT_CONFIG);
  const homeConfig = await loadFirstFromCandidates(createHomeCandidates(home));
  let packageConfig: DcpConfigWithRuleRefs | null = null;
  try {
    packageConfig = await loadCandidate({ path: join(cwd, "package.json"), kind: "package-json" });
  } catch (error) {
    getLogger().warn(`pi-dcp: failed to load config from ${join(cwd, "package.json")}: ${error}`);
  }
  const projectConfig = await loadFirstFromCandidates(createProjectCandidates(cwd));

  let config = withEnv;
  if (packageConfig) config = deepMerge(config, packageConfig);
  if (homeConfig) config = deepMerge(config, homeConfig);
  if (projectConfig) config = deepMerge(config, projectConfig);
  return config;
}

/**
 * Load configuration from extension settings, files, or defaults.
 */
export async function loadConfig(pi: ExtensionAPI): Promise<DcpConfigWithPruneRuleObjects> {
  const config = await loadConfigFromFiles();

  // Apply flag overrides (highest priority).
  const enabled = pi.getFlag("--dcp-enabled");
  const debug = pi.getFlag("--dcp-debug");
  if (enabled !== undefined) {
    config.enabled = enabled as boolean;
  }
  if (debug !== undefined) {
    config.debug = debug as boolean;
  }

  const availableRuleNames = getRuleNames();
  const invalidRuleNames: string[] = [];

  const rules: PruneRule[] = config.rules
    .filter((rule) => {
      if (isPruneRuleObject(rule)) return true;
      if (typeof rule === "string" && availableRuleNames.includes(rule)) return true;
      invalidRuleNames.push(typeof rule === "string" ? rule : JSON.stringify(rule));
      return false;
    })
    .map((rule) => (typeof rule === "string" ? getRule(rule)! : rule));

  if (config.debug && invalidRuleNames.length > 0) {
    getLogger().warn(
      `The following configured rules are invalid and will be ignored: ${invalidRuleNames.join(", ")}`
    );
  }

  return {
    ...config,
    rules,
  };
}

/**
 * Get default configuration (useful for testing or displaying defaults).
 */
export function getDefaultConfig(): DcpConfig {
  return { ...DEFAULT_CONFIG };
}

/**
 * Generate sample configuration file content.
 * Used by the init command to create dcp.config.ts.
 */
export function generateConfigFileContent(options?: { simplified?: boolean }): string {
  const simplified = options?.simplified ?? false;

  if (simplified) {
    return `/**
 * DCP (Dynamic Context Pruning) Configuration
 *
 * Place this file as:
 * - ./dcp.config.ts (project-specific)
 * - ~/.dcprc (user-wide)
 */

export default {
  enabled: true,
  debug: false,
  rules: ["deduplication", "superseded-writes", "error-purging", "tool-pairing", "recency"],
  keepRecentCount: 10,
};
`;
  }

  return `/**
 * DCP (Dynamic Context Pruning) Configuration
 *
 * This file configures the pi-dcp extension for intelligent context pruning.
 *
 * Place this file as:
 * - ./dcp.config.ts (project-specific configuration)
 * - ~/.dcprc (user-wide configuration)
 *
 * All fields are optional - defaults will be used for missing values.
 */

export default {
  // Enable/disable DCP entirely
  enabled: true,

  // Enable debug logging to see what gets pruned
  debug: false,

  // Rules to apply (in order of execution)
  // Available built-in rules:
  // - "deduplication": Remove duplicate tool outputs
  // - "superseded-writes": Remove older file versions
  // - "error-purging": Remove resolved errors
  // - "tool-pairing": Preserve tool_use/tool_result pairing (CRITICAL)
  // - "recency": Always keep recent messages
  rules: [
    "deduplication",
    "superseded-writes",
    "error-purging",
    "tool-pairing",
    "recency",
  ],

  // Number of recent messages to always keep (for recency rule)
  keepRecentCount: 10,
};
`;
}

/**
 * Write configuration file to the specified path.
 */
export async function writeConfigFile(
  path: string,
  options?: { force?: boolean; simplified?: boolean }
): Promise<void> {
  const force = options?.force ?? false;

  if (!force) {
    try {
      await readFile(path);
      throw new Error("Config file already exists. Use force option to overwrite.");
    } catch (error: any) {
      if (error.code !== "ENOENT") {
        throw error;
      }
    }
  }

  const content = generateConfigFileContent(options);
  await writeFile(path, content, "utf-8");
}
