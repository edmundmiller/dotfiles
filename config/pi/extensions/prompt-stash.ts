/**
 * Prompt Stash Extension
 *
 * Git-stash for your train of thought. Save prompt drafts, restore them later.
 * Stashes persist across sessions in ~/.pi/agent/prompt-stash.json
 *
 * Shortcuts:
 *   ctrl+s        → stash (opens editor dialog to capture text)
 *   ctrl+shift+s  → pop most recent stash to editor
 *
 * Commands:
 *   /stash              → list all stashes (interactive picker)
 *   /stash <text>       → save text directly as a stash
 *   /stash pop [n]      → pop stash n (default: 1) to editor
 *   /stash drop [n]     → drop stash n without restoring
 *   /stash clear        → clear all stashes
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

const STASH_FILE = join(homedir(), ".pi", "agent", "prompt-stash.json");

interface StashEntry {
  id: number;
  text: string;
  timestamp: number;
}

function loadStashes(): StashEntry[] {
  try {
    if (existsSync(STASH_FILE)) {
      return JSON.parse(readFileSync(STASH_FILE, "utf-8"));
    }
  } catch {}
  return [];
}

function saveStashes(stashes: StashEntry[]): void {
  const dir = dirname(STASH_FILE);
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  writeFileSync(STASH_FILE, JSON.stringify(stashes, null, 2), "utf-8");
}

function formatPreview(text: string, maxLen = 60): string {
  const oneLine = text.replace(/\n+/g, "↵ ").trim();
  return oneLine.length > maxLen ? oneLine.slice(0, maxLen) + "…" : oneLine;
}

function formatTime(ts: number): string {
  const d = new Date(ts);
  const now = new Date();
  const diffMs = now.getTime() - ts;
  const diffMins = Math.floor(diffMs / 60_000);
  if (diffMins < 1) return "just now";
  if (diffMins < 60) return `${diffMins}m ago`;
  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  return d.toLocaleDateString();
}

export default function (pi: ExtensionAPI) {
  let stashes: StashEntry[] = loadStashes();
  let nextId = stashes.length > 0 ? Math.max(...stashes.map((s) => s.id)) + 1 : 1;

  function pushStash(text: string): StashEntry {
    const entry: StashEntry = { id: nextId++, text, timestamp: Date.now() };
    stashes.unshift(entry); // most recent first
    saveStashes(stashes);
    return entry;
  }

  function updateStatus(ctx: ExtensionContext) {
    if (stashes.length === 0) {
      ctx.ui.setStatus("prompt-stash", undefined);
    } else {
      const theme = ctx.ui.theme;
      const count = theme.fg("accent", String(stashes.length));
      const label = theme.fg("dim", stashes.length === 1 ? " stash" : " stashes");
      ctx.ui.setStatus("prompt-stash", `stash: ${count}${label}`);
    }
  }

  // Reload stashes when session starts (picks up changes from other sessions)
  pi.on("session_start", async (_event, ctx) => {
    stashes = loadStashes();
    nextId = stashes.length > 0 ? Math.max(...stashes.map((s) => s.id)) + 1 : 1;
    updateStatus(ctx);
  });

  // ctrl+s → open editor dialog and stash whatever the user types/pastes
  pi.registerShortcut("ctrl+s", {
    description: "Stash: save a prompt draft",
    handler: async (ctx) => {
      const text = await ctx.ui.editor(
        "Stash Prompt Draft",
        "" // Paste or type your prompt to stash, then confirm
      );
      if (!text?.trim()) {
        ctx.ui.notify("Stash cancelled", "info");
        return;
      }
      const entry = pushStash(text.trim());
      updateStatus(ctx);
      ctx.ui.notify(
        `Stashed #${entry.id}  (${stashes.length} total)  —  ctrl+shift+s to restore`,
        "success"
      );
    },
  });

  // ctrl+shift+s → pop most recent stash to editor
  pi.registerShortcut("ctrl+shift+s", {
    description: "Stash: pop most recent draft to editor",
    handler: async (ctx) => {
      if (stashes.length === 0) {
        ctx.ui.notify("No stashes  —  ctrl+s to save one", "warning");
        return;
      }
      const entry = stashes.shift()!;
      saveStashes(stashes);
      updateStatus(ctx);
      ctx.ui.setEditorText(entry.text);
      ctx.ui.notify(`Stash #${entry.id} restored  (${stashes.length} remaining)`, "success");
    },
  });

  // /stash command
  pi.registerCommand("stash", {
    description: "Manage prompt stashes  (list · pop [n] · drop [n] · clear · <text>)",
    getArgumentCompletions: (prefix) => {
      const cmds = ["pop", "drop", "clear", "list"];
      const filtered = cmds.filter((c) => c.startsWith(prefix));
      return filtered.length > 0 ? filtered.map((c) => ({ value: c, label: c })) : null;
    },
    handler: async (args, ctx) => {
      const trimmed = args.trim();
      const parts = trimmed.split(/\s+/);
      const sub = parts[0];

      // /stash pop [n]
      if (sub === "pop") {
        const n = parts[1] ? parseInt(parts[1], 10) : 1;
        if (stashes.length === 0) {
          ctx.ui.notify("No stashes", "warning");
          return;
        }
        if (isNaN(n) || n < 1 || n > stashes.length) {
          ctx.ui.notify(
            `Index out of range. Have ${stashes.length} stash${stashes.length !== 1 ? "es" : ""}.`,
            "warning"
          );
          return;
        }
        const entry = stashes.splice(n - 1, 1)[0];
        saveStashes(stashes);
        updateStatus(ctx);
        ctx.ui.setEditorText(entry.text);
        ctx.ui.notify(`Stash ${n} restored to editor`, "success");
        return;
      }

      // /stash drop [n]
      if (sub === "drop") {
        const n = parts[1] ? parseInt(parts[1], 10) : 1;
        if (stashes.length === 0) {
          ctx.ui.notify("No stashes", "warning");
          return;
        }
        if (isNaN(n) || n < 1 || n > stashes.length) {
          ctx.ui.notify(
            `Index out of range. Have ${stashes.length} stash${stashes.length !== 1 ? "es" : ""}.`,
            "warning"
          );
          return;
        }
        const dropped = stashes.splice(n - 1, 1)[0];
        saveStashes(stashes);
        updateStatus(ctx);
        ctx.ui.notify(`Dropped stash ${n}: "${formatPreview(dropped.text, 40)}"`, "info");
        return;
      }

      // /stash clear
      if (sub === "clear") {
        if (stashes.length === 0) {
          ctx.ui.notify("No stashes to clear", "info");
          return;
        }
        const ok = await ctx.ui.confirm(
          "Clear all stashes?",
          `Delete all ${stashes.length} stash${stashes.length !== 1 ? "es" : ""}?`
        );
        if (ok) {
          stashes = [];
          saveStashes(stashes);
          updateStatus(ctx);
          ctx.ui.notify("All stashes cleared", "info");
        }
        return;
      }

      // /stash <text> (non-keyword args → save directly as stash)
      if (trimmed && sub !== "list") {
        const entry = pushStash(trimmed);
        updateStatus(ctx);
        ctx.ui.notify(
          `Stashed #${entry.id}: "${formatPreview(trimmed, 40)}"  (${stashes.length} total)`,
          "success"
        );
        return;
      }

      // /stash or /stash list → interactive picker
      if (stashes.length === 0) {
        ctx.ui.notify("No stashes  —  use ctrl+s or /stash <text> to save one", "info");
        return;
      }

      const items = stashes.map((s, i) => {
        const idx = `[${i + 1}]`;
        const when = formatTime(s.timestamp);
        const preview = formatPreview(s.text, 55);
        return `${idx} ${preview}  (${when})`;
      });

      const selected = await ctx.ui.select("Prompt Stashes", items);
      if (!selected) return;

      const idx = items.indexOf(selected);
      if (idx < 0) return;

      const entry = stashes[idx];
      const action = await ctx.ui.select(`Stash ${idx + 1}: "${formatPreview(entry.text, 40)}"`, [
        "Restore to editor",
        "View full text",
        "Delete",
      ]);

      if (action === "Restore to editor") {
        stashes.splice(idx, 1);
        saveStashes(stashes);
        updateStatus(ctx);
        ctx.ui.setEditorText(entry.text);
        ctx.ui.notify(`Stash ${idx + 1} restored`, "success");
      } else if (action === "View full text") {
        // Re-open editor in read-only style with full text pre-filled
        const edited = await ctx.ui.editor(
          "Stash (edit to update, confirm to save back)",
          entry.text
        );
        if (edited !== undefined && edited.trim() && edited.trim() !== entry.text) {
          stashes[idx] = { ...entry, text: edited.trim(), timestamp: Date.now() };
          saveStashes(stashes);
          ctx.ui.notify("Stash updated", "success");
        }
      } else if (action === "Delete") {
        stashes.splice(idx, 1);
        saveStashes(stashes);
        updateStatus(ctx);
        ctx.ui.notify(`Stash ${idx + 1} deleted`, "info");
      }
    },
  });
}
