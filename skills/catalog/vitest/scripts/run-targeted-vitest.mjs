#!/usr/bin/env node
import { existsSync } from "node:fs";
import { spawnSync } from "node:child_process";

const args = process.argv.slice(2);
const target = args[0];
if (target && target !== "--" && !existsSync(target.split(":")[0])) {
  console.error(`Missing test file: ${target}`);
  process.exit(2);
}

const extra = target ? args : [];
const candidates = [
  existsSync("bun.lock") || existsSync("bun.lockb") ? ["bunx", "vitest", "run", ...extra] : null,
  existsSync("pnpm-lock.yaml") ? ["pnpm", "exec", "vitest", "run", ...extra] : null,
  existsSync("yarn.lock") ? ["yarn", "vitest", "run", ...extra] : null,
  ["npx", "vitest", "run", ...extra],
].filter(Boolean);

for (const command of candidates) {
  const [bin, ...rest] = command;
  const result = spawnSync(bin, rest, { stdio: "inherit" });
  if (result.error?.code === "ENOENT") continue;
  process.exit(result.status ?? 1);
}

console.error("Could not find a Vitest runner: tried bunx, pnpm, yarn, npx.");
process.exit(127);
