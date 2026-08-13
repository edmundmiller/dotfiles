/**
 * Config discovery and repoRoot resolution.
 *
 * Reads review-box/config.json under XDG_CONFIG_HOME (fallback ~/.config).
 * XDG_CONFIG_HOME takes precedence when both exist (R8).
 * REVIEW_BOX_REPO_ROOT is NOT honored (R7).
 */

import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";

export function configDir(): string {
  const xdg = process.env.XDG_CONFIG_HOME;
  if (xdg && xdg.trim().length > 0) {
    return join(xdg, "review-box");
  }
  return join(homedir(), ".config", "review-box");
}

export function configPath(): string {
  return join(configDir(), "config.json");
}

type ConfigMapping = Record<string, string>;

export async function loadConfig(): Promise<ConfigMapping> {
  const path = configPath();
  let content: string;
  try {
    content = await readFile(path, "utf8");
  } catch (err: unknown) {
    if (err instanceof Error && "code" in err && (err as { code: string }).code === "ENOENT") {
      // Config file absent — treat as empty mapping
      return {};
    }
    throw err;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    throw new Error(`malformed config.json: ${path}`);
  }

  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new Error(`malformed config.json: expected a JSON object`);
  }

  return parsed as ConfigMapping;
}

/**
 * Resolve the repoRoot for a given repository from config.
 * Case-insensitive matching (GitHub names are case-insensitive, R5).
 * REVIEW_BOX_REPO_ROOT is NOT honored (R7).
 */
export async function resolveRepoRoot(repository: string): Promise<string> {
  const config = await loadConfig();

  const lowerRepo = repository.toLowerCase();
  let repoRoot: string | undefined;
  for (const [key, value] of Object.entries(config)) {
    if (key.toLowerCase() === lowerRepo) {
      repoRoot = value;
      break;
    }
  }

  if (!repoRoot) {
    throw new Error(`no repo root configured for repository: ${repository}`);
  }

  if (!existsSync(repoRoot)) {
    throw new Error(`configured repo root missing on disk: ${repoRoot}`);
  }

  return repoRoot;
}
