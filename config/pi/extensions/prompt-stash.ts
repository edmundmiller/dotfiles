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
import { homedir } from "node:os";
import { join } from "node:path";
import {
  formatPreview,
  formatTime,
  loadStashes,
  nextIdFromStashes,
  parseStashCommand,
  pushStash as purePushStash,
  saveStashes,
  type StashEntry,
} from "./prompt-stash-logic";

const STASH_FILE = join(homedir(), ".pi", "agent", "prompt-stash.json");

export default function (pi: ExtensionAPI) {
  let stashes: StashEntry[] = loadStashes(STASH_FILE);
  let nextId = nextIdFromStashes(stashes);

  function pushStash(text: string): StashEntry {
    const result = purePushStash(stashes, nextId, text);
    stashes = result.stashes;
    nextId = result.nextId;
    saveStashes(stashes, STASH_FILE);
    return result.entry;
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
    stashes = loadStashes(STASH_FILE);
    nextId = nextIdFromStashes(stashes);
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
      saveStashes(stashes, STASH_FILE);
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
      const action = parseStashCommand(args, stashes.length);

      if (action.type === "error") {
        ctx.ui.notify(action.message, "warning");
        return;
      }

      if (action.type === "pop") {
        const entry = stashes.splice(action.index, 1)[0];
        saveStashes(stashes, STASH_FILE);
        updateStatus(ctx);
        ctx.ui.setEditorText(entry.text);
        ctx.ui.notify(`Stash ${action.index + 1} restored to editor`, "success");
        return;
      }

      if (action.type === "drop") {
        const dropped = stashes.splice(action.index, 1)[0];
        saveStashes(stashes, STASH_FILE);
        updateStatus(ctx);
        ctx.ui.notify(
          `Dropped stash ${action.index + 1}: "${formatPreview(dropped.text, 40)}"`,
          "info"
        );
        return;
      }

      if (action.type === "clear") {
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
          saveStashes(stashes, STASH_FILE);
          updateStatus(ctx);
          ctx.ui.notify("All stashes cleared", "info");
        }
        return;
      }

      if (action.type === "save") {
        const entry = pushStash(action.text);
        updateStatus(ctx);
        ctx.ui.notify(
          `Stashed #${entry.id}: "${formatPreview(action.text, 40)}"  (${stashes.length} total)`,
          "success"
        );
        return;
      }

      // list
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
      const picked = await ctx.ui.select(`Stash ${idx + 1}: "${formatPreview(entry.text, 40)}"`, [
        "Restore to editor",
        "View full text",
        "Delete",
      ]);

      if (picked === "Restore to editor") {
        stashes.splice(idx, 1);
        saveStashes(stashes, STASH_FILE);
        updateStatus(ctx);
        ctx.ui.setEditorText(entry.text);
        ctx.ui.notify(`Stash ${idx + 1} restored`, "success");
      } else if (picked === "View full text") {
        // Re-open editor in read-only style with full text pre-filled
        const edited = await ctx.ui.editor(
          "Stash (edit to update, confirm to save back)",
          entry.text
        );
        if (edited !== undefined && edited.trim() && edited.trim() !== entry.text) {
          stashes[idx] = { ...entry, text: edited.trim(), timestamp: Date.now() };
          saveStashes(stashes, STASH_FILE);
          ctx.ui.notify("Stash updated", "success");
        }
      } else if (picked === "Delete") {
        stashes.splice(idx, 1);
        saveStashes(stashes, STASH_FILE);
        updateStatus(ctx);
        ctx.ui.notify(`Stash ${idx + 1} deleted`, "info");
      }
    },
  });
}
