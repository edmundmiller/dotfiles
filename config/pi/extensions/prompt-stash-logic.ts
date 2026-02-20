/**
 * prompt-stash — pure logic (no Pi SDK dependency)
 *
 * Extracted so tests can run without @mariozechner/pi-coding-agent.
 */

import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";

// NOTE: Pi loads every *.ts in ~/.pi/agent/extensions as an extension and
// expects a default-exported factory. Export a no-op so this shared logic
// file doesn't error at startup.
export default function (_pi: unknown) {
  // no-op
}

export interface StashEntry {
  id: number;
  text: string;
  timestamp: number;
}

export function loadStashes(filePath: string): StashEntry[] {
  try {
    if (existsSync(filePath)) {
      return JSON.parse(readFileSync(filePath, "utf-8"));
    }
  } catch {}
  return [];
}

export function saveStashes(stashes: StashEntry[], filePath: string): void {
  const dir = dirname(filePath);
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  writeFileSync(filePath, JSON.stringify(stashes, null, 2), "utf-8");
}

export function formatPreview(text: string, maxLen = 60): string {
  const oneLine = text.replace(/\n+/g, "↵ ").trim();
  return oneLine.length > maxLen ? oneLine.slice(0, maxLen) + "…" : oneLine;
}

/** now param allows deterministic testing without mocking Date */
export function formatTime(ts: number, now = Date.now()): string {
  const d = new Date(ts);
  const diffMs = now - ts;
  const diffMins = Math.floor(diffMs / 60_000);
  if (diffMins < 1) return "just now";
  if (diffMins < 60) return `${diffMins}m ago`;
  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  return d.toLocaleDateString();
}

export function nextIdFromStashes(stashes: StashEntry[]): number {
  return stashes.length > 0 ? Math.max(...stashes.map((s) => s.id)) + 1 : 1;
}

/** Pure push: returns the new entry and the updated stash array. */
export function pushStash(
  stashes: StashEntry[],
  nextId: number,
  text: string,
  timestamp = Date.now()
): { entry: StashEntry; stashes: StashEntry[]; nextId: number } {
  const entry: StashEntry = { id: nextId, text, timestamp };
  return { entry, stashes: [entry, ...stashes], nextId: nextId + 1 };
}

// ---------------------------------------------------------------------------
// Command routing — pure, returns a descriptor the handler executes
// ---------------------------------------------------------------------------

export type StashAction =
  | { type: "pop"; index: number }
  | { type: "drop"; index: number }
  | { type: "clear" }
  | { type: "save"; text: string }
  | { type: "list" }
  | { type: "error"; message: string };

export function parseStashCommand(args: string, stashCount: number): StashAction {
  const trimmed = args.trim();
  const parts = trimmed.split(/\s+/);
  const sub = parts[0];

  if (sub === "pop") {
    const n = parts[1] ? parseInt(parts[1], 10) : 1;
    if (stashCount === 0) return { type: "error", message: "No stashes" };
    if (isNaN(n) || n < 1 || n > stashCount)
      return {
        type: "error",
        message: `Index out of range. Have ${stashCount} stash${stashCount !== 1 ? "es" : ""}.`,
      };
    return { type: "pop", index: n - 1 };
  }

  if (sub === "drop") {
    const n = parts[1] ? parseInt(parts[1], 10) : 1;
    if (stashCount === 0) return { type: "error", message: "No stashes" };
    if (isNaN(n) || n < 1 || n > stashCount)
      return {
        type: "error",
        message: `Index out of range. Have ${stashCount} stash${stashCount !== 1 ? "es" : ""}.`,
      };
    return { type: "drop", index: n - 1 };
  }

  if (sub === "clear") return { type: "clear" };

  if (trimmed && sub !== "list") return { type: "save", text: trimmed };

  return { type: "list" };
}
