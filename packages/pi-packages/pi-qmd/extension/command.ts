/** Slash commands, panel wiring, and repo-scoped update/init flows for the QMD extension. */

import type {
  ExtensionAPI,
  ExtensionCommandContext,
  ExtensionContext,
} from "@mariozechner/pi-coding-agent";
import {
  deactivate_document,
  embed_pending,
  has_dot_segment,
  index_files,
  search_hybrid,
  search_lex,
  search_vector,
  update_collection,
} from "../core/qmd-store.js";
import type { FreshnessResult, RepoBindingResult } from "../core/types.js";
import { check_freshness, get_repo_head_commit } from "../domain/freshness.js";
import { build_draft_proposal, build_init_prompt, scan_repo } from "../domain/onboarding.js";
import {
  collection_key_from_repo_root,
  detect_repo_binding,
  read_repo_marker,
  resolve_repo_root,
  write_repo_marker,
} from "../domain/repo-binding.js";
import { QMD_PANEL_ALIAS, QMD_PANEL_SHORTCUT } from "../ui/constants.js";
import {
  build_qmd_panel_snapshot,
  normalize_hybrid_result,
  normalize_lex_result,
  normalize_vector_result,
} from "../ui/data.js";
import { show_qmd_panel } from "../ui/panel.js";
import { build_plain_text_summary } from "../ui/plain-text.js";
import { type QmdExtensionState, refresh_runtime_state } from "./runtime.js";
import { activate_qmd_init_tool } from "./tool.js";

function output_message(
  ctx: ExtensionContext | ExtensionCommandContext,
  message: string,
  level: "info" | "warning" | "error" = "info"
) {
  if (ctx.hasUI) {
    ctx.ui.notify(message, level);
    return;
  }
  console.log(message);
}

function render_freshness(freshness: FreshnessResult | undefined): string {
  if (!freshness) {
    return "freshness: unknown";
  }
  if (freshness.status === "fresh") {
    return "freshness: fresh";
  }
  if (freshness.status === "stale") {
    return `freshness: stale (${freshness.changed_count} markdown file(s))`;
  }
  return `freshness: unknown (${freshness.reason})`;
}

function render_status(binding: RepoBindingResult, freshness?: FreshnessResult): string {
  if (binding.status === "unavailable") {
    return `QMD unavailable\n${binding.reason}`;
  }

  if (binding.status === "not_indexed") {
    const lines = [`QMD status: not indexed`, `repo_root: ${binding.repo_root}`];
    lines.push(`suggested collection key: ${collection_key_from_repo_root(binding.repo_root)}`);
    lines.push("Next step: run /qmd init");
    return lines.join("\n");
  }

  return [
    "QMD status: indexed",
    `repo_root: ${binding.repo_root}`,
    `collection_key: ${binding.collection_key}`,
    `binding_source: ${binding.source}`,
    render_freshness(freshness),
  ].join("\n");
}

export function register_qmd_command(pi: ExtensionAPI, state: QmdExtensionState): void {
  let panel_open = false;
  let close_panel: (() => void) | null = null;

  // ── panel helpers ────────────────────────────────────────

  async function get_binding_and_freshness(
    cwd: string
  ): Promise<{ binding: RepoBindingResult; freshness: FreshnessResult | undefined }> {
    const binding = await detect_repo_binding(cwd);
    const freshness =
      binding.status === "indexed" && binding.marker
        ? await check_freshness(binding.marker)
        : undefined;
    state.last_binding = binding;
    state.last_freshness = freshness;
    return { binding, freshness };
  }

  async function run_update(ctx: ExtensionContext): Promise<void> {
    const binding = await detect_repo_binding(ctx.cwd);
    if (binding.status !== "indexed") return;

    const update_result = await update_collection(binding.collection_key);

    // Re-index dot-path files that QMD's scanner can't see
    const existing_marker = await read_repo_marker(binding.repo_root).catch(() => null);
    const extra = existing_marker?.extra_paths ?? [];
    if (extra.length > 0) {
      await index_files(binding.collection_key, binding.repo_root, extra);
    }

    if (update_result.needsEmbedding > 0 || extra.length > 0) {
      await embed_pending();
    }

    const now = new Date().toISOString();
    await write_repo_marker(binding.repo_root, {
      schema_version: 1,
      repo_root: binding.repo_root,
      collection_key: binding.collection_key,
      last_indexed_at: now,
      last_indexed_commit: (await get_repo_head_commit(binding.repo_root)) ?? "",
      created_at: existing_marker?.created_at ?? now,
      extra_paths: extra.length > 0 ? extra : undefined,
    });

    await refresh_runtime_state(ctx, state);
  }

  function start_init(ctx: ExtensionContext): void {
    (async () => {
      const binding = await detect_repo_binding(ctx.cwd);
      if (binding.status === "indexed") {
        output_message(ctx, "This repo already has a QMD binding.", "info");
        return;
      }
      if (binding.status === "unavailable") {
        output_message(ctx, render_status(binding), "warning");
        return;
      }

      const repo_root = await resolve_repo_root(ctx.cwd);
      const scan = await scan_repo(repo_root);
      const draft = build_draft_proposal(scan);
      state.init_workflow = { repo_root, prompt: build_init_prompt(scan, draft) };
      activate_qmd_init_tool(pi);

      const kickoff = [
        "Help me review a QMD onboarding proposal for this repository.",
        "Present the proposed collection setup and path contexts clearly.",
        "Ask for explicit confirmation before calling qmd_init.",
      ].join(" ");

      if (ctx.isIdle()) {
        pi.sendUserMessage(kickoff);
      } else {
        pi.sendUserMessage(kickoff, { deliverAs: "followUp" });
      }

      output_message(
        ctx,
        "Started /qmd init. Review the proposal in chat, then explicitly confirm before execution.",
        "info"
      );
    })();
  }

  async function open_or_toggle_panel(ctx: ExtensionContext): Promise<void> {
    if (panel_open && close_panel) {
      close_panel();
      return;
    }

    const { binding, freshness } = await get_binding_and_freshness(ctx.cwd);
    await refresh_runtime_state(ctx, state);

    if (!ctx.hasUI) {
      const snapshot = await build_qmd_panel_snapshot(ctx.cwd, binding, freshness);
      console.log(build_plain_text_summary(snapshot));
      return;
    }

    const initial_snapshot = await build_qmd_panel_snapshot(ctx.cwd, binding, freshness);
    panel_open = true;

    try {
      const panel_callbacks = {
        get_snapshot: async (selected_collection_key?: string) => {
          const fresh = await get_binding_and_freshness(ctx.cwd);
          await refresh_runtime_state(ctx, state);
          return build_qmd_panel_snapshot(
            ctx.cwd,
            fresh.binding,
            fresh.freshness,
            selected_collection_key
          );
        },
        on_update: () => run_update(ctx),
        on_init: () => start_init(ctx),
        on_close: () => {
          /* replaced by panel */
        },
        on_embed: async () => {
          await embed_pending();
          await refresh_runtime_state(ctx, state);
        },
        on_search_lex: async (query: string, collection: string) => {
          const raw = await search_lex(query, collection);
          return raw.map((r) => normalize_lex_result(r, collection));
        },
        on_search_vector: async (query: string, collection: string) => {
          const raw = await search_vector(query, collection);
          return raw.map((r) => normalize_vector_result(r, collection));
        },
        on_search_hybrid: async (query: string, collection: string) => {
          const raw = await search_hybrid(query, collection);
          return raw.map((r) => normalize_hybrid_result(r));
        },
        on_get_document: async (virtual_path: string) => {
          const { get_document_content } = await import("../core/qmd-store.js");
          return get_document_content(virtual_path);
        },
        on_toggle_files: async (adds: string[], removes: string[]) => {
          const binding = await detect_repo_binding(ctx.cwd);
          if (binding.status !== "indexed") return;

          // Deactivate removed files (fs paths → handlized internally)
          for (const fs_path of removes) {
            await deactivate_document(binding.collection_key, fs_path);
          }

          // Directly index added files (works for dotfiles too)
          if (adds.length > 0) {
            await index_files(binding.collection_key, binding.repo_root, adds);
            await embed_pending();
          }

          // Update extra_paths in marker — dot-path files need to be
          // re-indexed after every update_collection() call
          const existing_marker = await read_repo_marker(binding.repo_root).catch(() => null);
          const prev_extra = new Set<string>(existing_marker?.extra_paths ?? []);
          for (const p of adds.filter(has_dot_segment)) prev_extra.add(p);
          for (const p of removes.filter(has_dot_segment)) prev_extra.delete(p);
          const extra = [...prev_extra].sort();

          const now = new Date().toISOString();
          await write_repo_marker(binding.repo_root, {
            schema_version: 1,
            repo_root: binding.repo_root,
            collection_key: binding.collection_key,
            last_indexed_at: now,
            last_indexed_commit: (await get_repo_head_commit(binding.repo_root)) ?? "",
            created_at: existing_marker?.created_at ?? now,
            extra_paths: extra.length > 0 ? extra : undefined,
          });

          await refresh_runtime_state(ctx, state);
        },
      };

      close_panel = () => panel_callbacks.on_close();
      await show_qmd_panel(ctx, panel_callbacks, initial_snapshot);
    } catch {
      const snapshot = await build_qmd_panel_snapshot(ctx.cwd, binding, freshness);
      ctx.ui.notify("QMD panel failed to render.", "warning");
      ctx.ui.notify(build_plain_text_summary(snapshot), "info");
    } finally {
      panel_open = false;
      close_panel = null;
    }
  }

  // ── close panel helper (for lifecycle events) ────────────

  state.close_panel = () => {
    if (close_panel) {
      close_panel();
      close_panel = null;
    }
    panel_open = false;
  };

  // ── commands ──────────────────────────────────────────────

  pi.registerCommand("qmd", {
    description: "QMD index dashboard · subcommands: status, update, init",
    handler: async (args, ctx) => {
      const sub_command = (args ?? "").trim();

      // No args → open panel
      if (!sub_command) {
        await open_or_toggle_panel(ctx);
        return;
      }

      if (sub_command === "status") {
        const { binding, freshness } = await get_binding_and_freshness(ctx.cwd);
        await refresh_runtime_state(ctx, state);
        output_message(ctx, render_status(binding, freshness), "info");
        return;
      }

      if (sub_command === "update") {
        const binding = await detect_repo_binding(ctx.cwd);
        if (binding.status !== "indexed") {
          output_message(
            ctx,
            render_status(binding),
            binding.status === "unavailable" ? "warning" : "info"
          );
          return;
        }

        output_message(ctx, `Updating QMD collection ${binding.collection_key}...`, "info");
        await run_update(ctx);
        const { binding: updated_binding } = await get_binding_and_freshness(ctx.cwd);
        const update_lines = [
          `QMD update complete for ${updated_binding.status === "indexed" ? updated_binding.collection_key : "collection"}.`,
        ];
        output_message(ctx, update_lines.join("\n"), "info");
        return;
      }

      if (sub_command === "init") {
        start_init(ctx);
        return;
      }

      output_message(ctx, "Usage: /qmd [status | update | init]", "info");
    },
  });

  pi.registerCommand(QMD_PANEL_ALIAS, {
    description: "Alias for /qmd — open QMD index dashboard",
    handler: async (_args, ctx) => {
      await open_or_toggle_panel(ctx);
    },
  });

  pi.registerShortcut(QMD_PANEL_SHORTCUT, {
    description: "Toggle the QMD index dashboard",
    handler: async (ctx) => {
      await open_or_toggle_panel(ctx);
    },
  });
}
