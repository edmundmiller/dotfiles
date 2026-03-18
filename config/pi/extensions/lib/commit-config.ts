/**
 * Commit extension config helpers.
 *
 * Stores lightweight JSON config for commit-related pi extensions without
 * depending on extra npm packages.
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import path from "node:path";

export interface CommitConfig {
  mode?: string;
  prompt?: string;
  maxOutputCost?: number;
}

const CONFIG_DIR = path.join(homedir(), ".pi", "agent", "config");
const CONFIG_PATH = path.join(CONFIG_DIR, "generate-commit-message.json");

function isString(value: unknown): value is string {
  return typeof value === "string";
}

function isNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value);
}

export function loadCommitConfig(defaults: CommitConfig): CommitConfig {
  const config: CommitConfig = { ...defaults };
  if (!existsSync(CONFIG_PATH)) return config;

  try {
    const parsed = JSON.parse(readFileSync(CONFIG_PATH, "utf8"));
    if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
      return config;
    }

    const mode = Reflect.get(parsed, "mode");
    const prompt = Reflect.get(parsed, "prompt");
    const maxOutputCost = Reflect.get(parsed, "maxOutputCost");

    if (isString(mode)) config.mode = mode;
    if (isString(prompt)) config.prompt = prompt;
    if (isNumber(maxOutputCost)) config.maxOutputCost = maxOutputCost;

    return config;
  } catch {
    return config;
  }
}

export function saveCommitConfig(config: CommitConfig): void {
  mkdirSync(CONFIG_DIR, { recursive: true });
  writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2) + "\n", "utf8");
}
