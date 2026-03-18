/** Interactive split-pane TUI for browsing QMD collections, files, and search results. */

import type { ExtensionContext, Theme, ThemeColor } from "@mariozechner/pi-coding-agent";
import { exec } from "node:child_process";
import { matchesKey, type TUI, truncateToWidth, visibleWidth } from "@mariozechner/pi-tui";
import {
  QMD_PANEL_ICON,
  QMD_PANEL_MIN_WIDTH,
  QMD_PANEL_SHORTCUT,
  QMD_PANEL_WIDTH,
  QMD_SIDEBAR_INNER_WIDTH,
} from "./constants.js";
import type {
  FileTreeNode,
  FlatTreeEntry,
  QmdCollectionSummary,
  QmdPanelSnapshot,
  QmdSearchResult,
} from "./data.js";
import { build_file_tree, collect_file_paths, flatten_tree, format_relative_time } from "./data.js";
import { ToggleState } from "./toggle-state.js";

export interface QmdPanelCallbacks {
  get_snapshot: (selected_collection_key?: string) => Promise<QmdPanelSnapshot>;
  on_update: () => Promise<void>;
  on_init: () => void;
  on_close: () => void;
  on_toggle_files: (adds: string[], removes: string[]) => Promise<void>;
  on_embed: () => Promise<void>;
  on_search_lex: (query: string, collection: string) => Promise<QmdSearchResult[]>;
  on_search_vector: (query: string, collection: string) => Promise<QmdSearchResult[]>;
  on_search_hybrid: (query: string, collection: string) => Promise<QmdSearchResult[]>;
  on_get_document: (virtual_path: string) => Promise<{ content: string; title: string } | null>;
}

export async function show_qmd_panel(
  ctx: Pick<ExtensionContext, "ui">,
  callbacks: QmdPanelCallbacks,
  initial_snapshot: QmdPanelSnapshot
): Promise<void> {
  await ctx.ui.custom(
    (tui: TUI, theme: Theme, _keybindings: unknown, done: (_result: unknown) => void) => {
      const close = () => done(undefined);
      const panel = new QmdPanel(tui, theme, callbacks, close, initial_snapshot);
      callbacks.on_close = close;
      return panel;
    },
    {
      overlay: true,
      overlayOptions: {
        anchor: "center",
        width: QMD_PANEL_WIDTH,
        minWidth: QMD_PANEL_MIN_WIDTH,
        maxHeight: "80%",
      },
    }
  );
}

export class QmdPanel {
  private readonly tui: TUI;
  private readonly theme: Theme;
  private readonly callbacks: QmdPanelCallbacks;
  private readonly done: () => void;
  private snapshot: QmdPanelSnapshot;

  // ── Focus & view state ──────────────────────────────────
  private focused_pane: "sidebar" | "main" = "main";
  private main_view: "overview" | "files" | "search" | "preview" = "overview";
  private updating = false;
  private update_progress: string | null = null;

  // ── Sidebar state ───────────────────────────────────────
  private selected_collection_key: string | null;
  private sidebar_cursor = 0;
  private sidebar_scroll_offset = 0;
  private sidebar_filter_query = "";
  private sidebar_filter_editing = false;

  private overview_scroll_offset = 0;
  private overview_content_lines: string[] = [];

  // ── Tree view state ─────────────────────────────────────
  private tree_roots: FileTreeNode[] = [];
  private tree_collapsed: Set<string> = new Set();
  private tree_flat: FlatTreeEntry[] = [];
  private tree_cursor = 0;
  private tree_scroll_offset = 0;

  // ── Search state ────────────────────────────────────────
  private search_query = "";
  private search_results: QmdSearchResult[] = [];
  private search_loading = false;
  private search_cursor = 0;
  private search_scroll_offset = 0;
  private search_mode: "lex" | "vector" | "hybrid" = "hybrid";
  private search_focus: "input" | "results" = "input";

  // ── Preview state ───────────────────────────────────────
  private preview_content: string[] = [];
  private preview_raw_lines: string[] = [];
  private preview_scroll_offset = 0;
  private preview_path = "";
  private preview_target_line = 0;
  private preview_loading = false;
  private preview_focused = false;
  private preview_generation = 0;

  // ── Toggle state ────────────────────────────────────────
  private toggle: ToggleState = new ToggleState([]);

  constructor(
    tui: TUI,
    theme: Theme,
    callbacks: QmdPanelCallbacks,
    done: () => void,
    initial_snapshot: QmdPanelSnapshot
  ) {
    this.tui = tui;
    this.theme = theme;
    this.callbacks = callbacks;
    this.done = done;
    this.snapshot = initial_snapshot;
    this.selected_collection_key = initial_snapshot.collection_key;

    // Position sidebar cursor on the bound collection (or "All" if none)
    this.sync_sidebar_cursor_to_selection();
  }

  // ═══════════════════════════════════════════════════════════
  // Input handling
  // ═══════════════════════════════════════════════════════════

  handleInput(key_data: string): void {
    // Global close keys
    if (matchesKey(key_data, "ctrl+c") || matchesKey(key_data, QMD_PANEL_SHORTCUT)) {
      this.done();
      return;
    }
    if (
      matchesKey(key_data, "q") &&
      !this.sidebar_filter_editing &&
      !(
        (this.main_view === "search" || this.main_view === "preview") &&
        this.focused_pane === "main"
      )
    ) {
      this.done();
      return;
    }

    // Route to focused pane
    if (this.focused_pane === "sidebar") {
      this.handle_sidebar_input(key_data);
    } else {
      this.handle_main_input(key_data);
    }
  }

  // ── Sidebar input ───────────────────────────────────────

  private handle_sidebar_input(key_data: string): void {
    // Filter typing mode
    if (this.sidebar_filter_editing) {
      if (matchesKey(key_data, "enter")) {
        this.sidebar_filter_editing = false;
        this.tui.requestRender();
        return;
      }
      if (matchesKey(key_data, "escape")) {
        this.sidebar_filter_editing = false;
        this.sidebar_filter_query = "";
        this.sync_sidebar_cursor_to_selection();
        this.tui.requestRender();
        return;
      }
      if (matchesKey(key_data, "backspace")) {
        if (this.sidebar_filter_query.length > 0) {
          this.sidebar_filter_query = this.sidebar_filter_query.slice(0, -1);
          this.sidebar_cursor = 0;
          this.sidebar_scroll_offset = 0;
        }
        this.tui.requestRender();
        return;
      }
      if (matchesKey(key_data, "ctrl+u")) {
        this.sidebar_filter_query = "";
        this.sidebar_cursor = 0;
        this.sidebar_scroll_offset = 0;
        this.tui.requestRender();
        return;
      }
      const ch = get_printable_char(key_data);
      if (ch) {
        this.sidebar_filter_query += ch;
        this.sidebar_cursor = 0;
        this.sidebar_scroll_offset = 0;
        this.tui.requestRender();
      }
      return;
    }

    // Normal sidebar keys
    if (matchesKey(key_data, "escape")) {
      if (this.sidebar_filter_query.length > 0) {
        this.sidebar_filter_query = "";
        this.sync_sidebar_cursor_to_selection();
        this.tui.requestRender();
        return;
      }
      this.done();
      return;
    }

    if (get_printable_char(key_data) === "/") {
      this.sidebar_filter_editing = true;
      this.tui.requestRender();
      return;
    }

    if (matchesKey(key_data, "j") || matchesKey(key_data, "down")) {
      this.sidebar_move_cursor(1);
      return;
    }
    if (matchesKey(key_data, "k") || matchesKey(key_data, "up")) {
      this.sidebar_move_cursor(-1);
      return;
    }
    if (matchesKey(key_data, "g") || matchesKey(key_data, "home")) {
      this.sidebar_set_cursor(0);
      return;
    }
    if (matchesKey(key_data, "shift+g") || matchesKey(key_data, "end")) {
      this.sidebar_set_cursor(this.get_sidebar_entries().length - 1);
      return;
    }

    if (
      matchesKey(key_data, "enter") ||
      matchesKey(key_data, "right") ||
      matchesKey(key_data, "l")
    ) {
      this.select_sidebar_entry();
      this.focused_pane = "main";
      this.tui.requestRender();
      return;
    }

    if (matchesKey(key_data, "u") && this.snapshot.supports_update_action) {
      this.start_update();
      return;
    }

    if (matchesKey(key_data, "r")) {
      this.refresh();
      return;
    }

    if (matchesKey(key_data, "i") && this.snapshot.binding_status === "not_indexed") {
      this.done();
      this.callbacks.on_init();
      return;
    }
  }

  // ── Main pane input ─────────────────────────────────────

  private handle_main_input(key_data: string): void {
    if (this.main_view === "overview") {
      this.handle_main_overview_input(key_data);
    } else if (this.main_view === "files") {
      this.handle_main_files_input(key_data);
    } else if (this.main_view === "preview") {
      // 3-column mode: route to preview or search based on focus
      if (this.preview_focused) {
        this.handle_main_preview_input(key_data);
      } else {
        this.handle_main_search_input(key_data);
      }
    } else if (this.main_view === "search") {
      this.handle_main_search_input(key_data);
    }
  }

  private handle_main_overview_input(key_data: string): void {
    if (
      matchesKey(key_data, "escape") ||
      matchesKey(key_data, "left") ||
      matchesKey(key_data, "h")
    ) {
      this.focused_pane = "sidebar";
      this.tui.requestRender();
      return;
    }
    if (
      (matchesKey(key_data, "s") || get_printable_char(key_data) === "/") &&
      this.selected_collection_key
    ) {
      this.main_view = "search";
      this.search_query = "";
      this.search_results = [];
      this.search_focus = "input";
      this.search_cursor = 0;
      this.search_scroll_offset = 0;
      this.tui.requestRender();
      return;
    }
    if (
      (matchesKey(key_data, "f") || matchesKey(key_data, "enter")) &&
      this.selected_collection_key &&
      this.snapshot.filesystem_paths.length > 0
    ) {
      this.open_tree_view();
      this.main_view = "files";
      this.tui.requestRender();
      return;
    }
    if (matchesKey(key_data, "u") && this.snapshot.supports_update_action) {
      this.start_update();
      return;
    }
    if (matchesKey(key_data, "r")) {
      this.refresh();
      return;
    }
    if (matchesKey(key_data, "i") && this.snapshot.binding_status === "not_indexed") {
      this.done();
      this.callbacks.on_init();
      return;
    }
    // Scroll
    this.handle_overview_scroll(key_data);
  }

  private handle_main_files_input(key_data: string): void {
    if (matchesKey(key_data, "escape")) {
      this.toggle.clear();
      this.main_view = "overview";
      this.overview_scroll_offset = 0;
      this.tui.requestRender();
      return;
    }
    if (matchesKey(key_data, "h") || matchesKey(key_data, "left")) {
      this.focused_pane = "sidebar";
      this.tui.requestRender();
      return;
    }
    if (
      matchesKey(key_data, "enter") ||
      matchesKey(key_data, "l") ||
      matchesKey(key_data, "right")
    ) {
      this.tree_toggle_expand();
      return;
    }
    if (matchesKey(key_data, "space") && this.snapshot.supports_file_toggling) {
      this.tree_toggle_inclusion();
      return;
    }
    if (matchesKey(key_data, "a") && this.snapshot.supports_file_toggling) {
      if (this.toggle.has_pending()) {
        this.apply_pending_changes();
      }
      return;
    }
    if (matchesKey(key_data, "j") || matchesKey(key_data, "down")) {
      this.tree_move_cursor(1);
      return;
    }
    if (matchesKey(key_data, "k") || matchesKey(key_data, "up")) {
      this.tree_move_cursor(-1);
      return;
    }
    if (matchesKey(key_data, "g") || matchesKey(key_data, "home")) {
      this.tree_set_cursor(0);
      return;
    }
    if (matchesKey(key_data, "shift+g") || matchesKey(key_data, "end")) {
      this.tree_set_cursor(this.tree_flat.length - 1);
      return;
    }
    if (matchesKey(key_data, "r")) {
      this.refresh();
      return;
    }
  }

  // ── Search input ────────────────────────────────────────

  private handle_main_search_input(key_data: string): void {
    if (this.search_focus === "input") {
      // Left arrow from input → sidebar (h is a typed char, so only arrow key)
      if (matchesKey(key_data, "left")) {
        this.focused_pane = "sidebar";
        this.tui.requestRender();
        return;
      }
      if (matchesKey(key_data, "escape")) {
        if (this.search_query.length > 0) {
          this.search_query = "";
          this.search_results = [];
          this.close_preview_if_open();
          this.tui.requestRender();
          return;
        }
        // Empty query: close preview first, then overview
        if (this.main_view === "preview") {
          this.close_preview_if_open();
          this.tui.requestRender();
          return;
        }
        this.main_view = "overview";
        this.overview_scroll_offset = 0;
        this.tui.requestRender();
        return;
      }
      if (matchesKey(key_data, "enter")) {
        this.execute_search();
        return;
      }
      if (matchesKey(key_data, "down") && this.search_results.length > 0) {
        this.search_focus = "results";
        this.search_cursor = 0;
        this.tui.requestRender();
        return;
      }
      if (matchesKey(key_data, "ctrl+t")) {
        this.cycle_search_mode();
        this.tui.requestRender();
        return;
      }
      if (matchesKey(key_data, "backspace")) {
        if (this.search_query.length > 0) {
          this.search_query = this.search_query.slice(0, -1);
        }
        this.tui.requestRender();
        return;
      }
      if (matchesKey(key_data, "ctrl+u")) {
        this.search_query = "";
        this.search_results = [];
        this.close_preview_if_open();
        this.tui.requestRender();
        return;
      }
      // Don't accept input while searching
      if (this.search_loading) return;
      const ch = get_printable_char(key_data);
      if (ch) {
        this.search_query += ch;
        this.tui.requestRender();
      }
      return;
    }

    // search_focus === "results"
    if (matchesKey(key_data, "h") || matchesKey(key_data, "left")) {
      this.focused_pane = "sidebar";
      this.tui.requestRender();
      return;
    }
    if (matchesKey(key_data, "escape") || matchesKey(key_data, "up")) {
      if (matchesKey(key_data, "up") && this.search_cursor > 0) {
        this.search_cursor--;
        this.auto_update_preview();
        this.tui.requestRender();
        return;
      }
      this.search_focus = "input";
      this.tui.requestRender();
      return;
    }
    if (matchesKey(key_data, "j") || matchesKey(key_data, "down")) {
      if (this.search_cursor < this.search_results.length - 1) {
        this.search_cursor++;
        this.auto_update_preview();
        this.tui.requestRender();
      }
      return;
    }
    if (matchesKey(key_data, "k")) {
      if (this.search_cursor > 0) {
        this.search_cursor--;
        this.auto_update_preview();
        this.tui.requestRender();
      } else {
        this.search_focus = "input";
        this.tui.requestRender();
      }
      return;
    }
    if (
      matchesKey(key_data, "enter") ||
      matchesKey(key_data, "l") ||
      matchesKey(key_data, "right")
    ) {
      const result = this.search_results[this.search_cursor];
      if (result) {
        if (this.main_view === "preview") {
          // Already in 3-col: just focus the preview pane
          this.preview_focused = true;
          this.tui.requestRender();
        } else {
          this.open_preview(result);
        }
      }
      return;
    }
    if (matchesKey(key_data, "y")) {
      const result = this.search_results[this.search_cursor];
      if (result) {
        this.copy_to_clipboard(result.display_path);
      }
      return;
    }
  }

  private close_preview_if_open(): void {
    if (this.main_view === "preview") {
      this.main_view = "search";
      this.preview_focused = false;
    }
  }

  private auto_update_preview(): void {
    if (this.main_view !== "preview") return;
    const result = this.search_results[this.search_cursor];
    if (result) this.open_preview(result, false);
  }

  private cycle_search_mode(): void {
    const modes: Array<"lex" | "vector" | "hybrid"> = ["hybrid", "lex", "vector"];
    const idx = modes.indexOf(this.search_mode);
    this.search_mode = modes[(idx + 1) % modes.length];
  }

  private async execute_search(): Promise<void> {
    if (!this.search_query.trim() || !this.selected_collection_key) return;
    this.search_loading = true;
    this.tui.requestRender();
    try {
      let callback: (query: string, collection: string) => Promise<QmdSearchResult[]>;
      if (this.search_mode === "hybrid") {
        callback = this.callbacks.on_search_hybrid;
      } else if (this.search_mode === "vector") {
        callback = this.callbacks.on_search_vector;
      } else {
        callback = this.callbacks.on_search_lex;
      }
      this.search_results = await callback(this.search_query, this.selected_collection_key);
      if (this.search_results.length > 0) {
        this.search_focus = "results";
        // Auto-update preview with first result if in 3-col mode
        if (this.main_view === "preview") {
          const first = this.search_results[0];
          if (first) this.open_preview(first, false);
        }
      } else if (this.main_view === "preview") {
        // No results: close preview
        this.close_preview_if_open();
      }
    } catch {
      this.search_results = [];
      this.close_preview_if_open();
    } finally {
      this.search_loading = false;
      this.search_cursor = 0;
      this.search_scroll_offset = 0;
      this.tui.requestRender();
    }
  }

  private copy_to_clipboard(text: string): void {
    exec(`printf '%s' ${JSON.stringify(text)} | pbcopy`);
  }

  // ── Overview scroll ─────────────────────────────────────

  private handle_overview_scroll(key_data: string): void {
    if (matchesKey(key_data, "j") || matchesKey(key_data, "down")) {
      this.overview_scroll_offset++;
      this.tui.requestRender();
      return;
    }
    if (matchesKey(key_data, "k") || matchesKey(key_data, "up")) {
      this.overview_scroll_offset = Math.max(0, this.overview_scroll_offset - 1);
      this.tui.requestRender();
      return;
    }
    if (matchesKey(key_data, "g") || matchesKey(key_data, "home")) {
      this.overview_scroll_offset = 0;
      this.tui.requestRender();
      return;
    }
    if (matchesKey(key_data, "shift+g") || matchesKey(key_data, "end")) {
      this.overview_scroll_offset = 999;
      this.tui.requestRender();
      return;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Rendering — top-level
  // ═══════════════════════════════════════════════════════════

  render(width: number): string[] {
    if (this.updating) {
      return this.render_updating_view(width);
    }

    const t = this.theme;
    const w = Math.max(QMD_PANEL_MIN_WIDTH, width);
    const sidebar_w = QMD_SIDEBAR_INNER_WIDTH;
    const max_h = this.get_max_height();
    // body_h = max_h - top border(1) - footer_sep(1) - footer(1) - bottom border(1)
    const body_h = Math.max(4, max_h - 4);
    const bdr = (s: string) => t.fg("borderMuted", s);

    const is_three_col = this.main_view === "preview";

    // ── Column widths ───────────────────────────────────
    let main_w = 0;
    let search_w = 0;
    let preview_w = 0;

    if (is_three_col) {
      // 4 border columns: │sidebar│search│preview│
      const combined = w - sidebar_w - 4;
      search_w = Math.max(30, Math.floor(combined * 0.38));
      preview_w = combined - search_w;
    } else {
      // 3 border columns: │sidebar│main│
      main_w = w - sidebar_w - 3;
    }

    // ── Render pane contents ────────────────────────────
    const sidebar_lines = this.render_sidebar(sidebar_w, body_h);
    let main_lines: string[] = [];
    let search_lines: string[] = [];
    let preview_lines: string[] = [];

    if (is_three_col) {
      search_lines = this.render_main_search(search_w, body_h);
      preview_lines = this.render_main_preview(preview_w, body_h);
    } else {
      main_lines = this.render_main_pane(main_w, body_h);
    }

    // ── Top border ──────────────────────────────────────
    const sb_label_text = "Collections";
    const sb_focused = this.focused_pane === "sidebar";
    const sb_label = sb_focused ? t.fg("accent", sb_label_text) : t.fg("dim", sb_label_text);
    const sb_label_vis = visibleWidth(sb_label_text);
    const sb_fill = Math.max(0, sidebar_w - sb_label_vis - 2);

    let top_border: string;
    let footer_inner_w: number;

    if (is_three_col) {
      const search_label_text = `${display_key(this.selected_collection_key ?? "", 16)} › Search`;
      const preview_label_text = "Preview";
      const search_is_focused = this.focused_pane === "main" && !this.preview_focused;
      const preview_is_focused = this.focused_pane === "main" && this.preview_focused;
      const search_label = search_is_focused
        ? t.fg("accent", search_label_text)
        : t.fg("dim", search_label_text);
      const preview_label = preview_is_focused
        ? t.fg("accent", preview_label_text)
        : t.fg("dim", preview_label_text);
      const search_label_vis = visibleWidth(search_label_text);
      const preview_label_vis = visibleWidth(preview_label_text);
      const search_fill = Math.max(0, search_w - search_label_vis - 2);
      const preview_fill = Math.max(0, preview_w - preview_label_vis - 2);
      top_border = truncateToWidth(
        `${bdr("╭─")} ${sb_label} ${bdr("─".repeat(sb_fill))}${bdr("┬─")} ${search_label} ${bdr("─".repeat(search_fill))}${bdr("┬─")} ${preview_label} ${bdr("─".repeat(preview_fill))}${bdr("╮")}`,
        w
      );
      footer_inner_w = sidebar_w + search_w + preview_w + 2;
    } else {
      const main_label_text = this.get_main_pane_label();
      const main_label =
        this.focused_pane === "main"
          ? t.fg("accent", main_label_text)
          : t.fg("dim", main_label_text);
      const main_label_vis = visibleWidth(main_label_text);
      const main_fill = Math.max(0, main_w - main_label_vis - 2);
      top_border = truncateToWidth(
        `${bdr("╭─")} ${sb_label} ${bdr("─".repeat(sb_fill))}${bdr("┬─")} ${main_label} ${bdr("─".repeat(main_fill))}${bdr("╮")}`,
        w
      );
      footer_inner_w = sidebar_w + main_w + 1;
    }

    // ── Body lines ──────────────────────────────────────
    const body: string[] = [];
    for (let i = 0; i < body_h; i++) {
      const sl = pad_to_width(truncateToWidth(sidebar_lines[i] ?? "", sidebar_w), sidebar_w);
      if (is_three_col) {
        const srch = pad_to_width(truncateToWidth(search_lines[i] ?? "", search_w), search_w);
        const prev = pad_to_width(truncateToWidth(preview_lines[i] ?? "", preview_w), preview_w);
        body.push(
          truncateToWidth(`${bdr("│")}${sl}${bdr("│")}${srch}${bdr("│")}${prev}${bdr("│")}`, w)
        );
      } else {
        const ml = pad_to_width(truncateToWidth(main_lines[i] ?? "", main_w), main_w);
        body.push(truncateToWidth(`${bdr("│")}${sl}${bdr("│")}${ml}${bdr("│")}`, w));
      }
    }

    // ── Footer separator ────────────────────────────────
    let footer_sep: string;
    if (is_three_col) {
      footer_sep = truncateToWidth(
        `${bdr("├")}${bdr("─".repeat(sidebar_w))}${bdr("┴")}${bdr("─".repeat(search_w))}${bdr("┴")}${bdr("─".repeat(preview_w))}${bdr("┤")}`,
        w
      );
    } else {
      footer_sep = truncateToWidth(
        `${bdr("├")}${bdr("─".repeat(sidebar_w))}${bdr("┴")}${bdr("─".repeat(main_w))}${bdr("┤")}`,
        w
      );
    }

    // ── Footer content ──────────────────────────────────
    const footer_text = this.render_footer(footer_inner_w);
    const footer_line = truncateToWidth(
      `${bdr("│")}${pad_to_width(truncateToWidth(footer_text, footer_inner_w), footer_inner_w)}${bdr("│")}`,
      w
    );

    // ── Bottom border ───────────────────────────────────
    const bot_border = truncateToWidth(
      `${bdr("╰")}${bdr("─".repeat(footer_inner_w))}${bdr("╯")}`,
      w
    );

    return [top_border, ...body, footer_sep, footer_line, bot_border];
  }

  invalidate(): void {}

  // ═══════════════════════════════════════════════════════════
  // Sidebar rendering
  // ═══════════════════════════════════════════════════════════

  private render_sidebar(width: number, height: number): string[] {
    const t = this.theme;
    const lines: string[] = [];
    const entries = this.get_sidebar_entries();
    const total_entries = entries.length;

    // Reserve bottom line for filter when editing
    const list_height = this.sidebar_filter_editing ? height - 1 : height;

    // Ensure cursor is visible
    this.sidebar_cursor = Math.max(0, Math.min(this.sidebar_cursor, total_entries - 1));
    if (this.sidebar_cursor < this.sidebar_scroll_offset) {
      this.sidebar_scroll_offset = this.sidebar_cursor;
    } else if (this.sidebar_cursor >= this.sidebar_scroll_offset + list_height) {
      this.sidebar_scroll_offset = this.sidebar_cursor - list_height + 1;
    }
    this.sidebar_scroll_offset = Math.max(
      0,
      Math.min(this.sidebar_scroll_offset, Math.max(0, total_entries - list_height))
    );

    // Blank top line
    lines.push("");

    const visible = entries.slice(
      this.sidebar_scroll_offset,
      this.sidebar_scroll_offset + list_height - 1
    );
    for (let i = 0; i < visible.length; i++) {
      const entry = visible[i];
      const abs_idx = this.sidebar_scroll_offset + i;
      const is_cursor = abs_idx === this.sidebar_cursor;

      if (entry.type === "all") {
        const marker = is_cursor ? t.fg("accent", "▸") : " ";
        const label = is_cursor
          ? t.fg("accent", t.bold(`All (${this.snapshot.collections.length})`))
          : `All (${this.snapshot.collections.length})`;
        lines.push(truncateToWidth(` ${marker} ${label}`, width));
      } else {
        const marker = is_cursor ? t.fg("accent", "▸") : " ";
        const bound = entry.collection.is_bound_collection ? t.fg("accent", "●") : " ";
        const count = `${entry.collection.doc_count}`;
        const name_max = width - 7 - count.length; // " ▸ name  ● count"
        const name_raw = display_key(entry.collection.key, Math.max(4, name_max));
        const name = is_cursor ? t.fg("accent", t.bold(name_raw)) : name_raw;
        const name_vis = visibleWidth(name);
        const count_vis = count.length;
        const gap = Math.max(1, width - 4 - name_vis - 1 - count_vis - 1); // marker(2) + space(1) + name + gap + bound(1) + count + space(1)
        lines.push(
          truncateToWidth(
            ` ${marker} ${name}${" ".repeat(gap)}${bound} ${t.fg("dim", count)}`,
            width
          )
        );
      }
    }

    // Fill remaining list height
    const used = lines.length;
    const remaining_list = list_height - used;
    for (let i = 0; i < remaining_list; i++) {
      lines.push("");
    }

    // Filter line
    if (this.sidebar_filter_editing) {
      const filter_input = `/${this.sidebar_filter_query}█`;
      lines.push(truncateToWidth(` ${t.fg("accent", filter_input)}`, width));
    }

    // Pad to exact height
    while (lines.length < height) {
      lines.push("");
    }

    return lines.slice(0, height);
  }

  private get_sidebar_entries(): Array<
    { type: "all" } | { type: "collection"; collection: QmdCollectionSummary }
  > {
    const query = this.sidebar_filter_query.trim().toLowerCase();
    const entries: Array<
      { type: "all" } | { type: "collection"; collection: QmdCollectionSummary }
    > = [];

    if (!query) {
      entries.push({ type: "all" });
      for (const c of this.snapshot.collections) {
        entries.push({ type: "collection", collection: c });
      }
    } else {
      // Filter mode: show matching collections only (no "All")
      for (const c of this.snapshot.collections) {
        if (c.key.toLowerCase().includes(query)) {
          entries.push({ type: "collection", collection: c });
        }
      }
    }
    return entries;
  }

  private sidebar_move_cursor(delta: number): void {
    const entries = this.get_sidebar_entries();
    if (entries.length === 0) return;
    const next = Math.max(0, Math.min(this.sidebar_cursor + delta, entries.length - 1));
    if (next === this.sidebar_cursor) return;
    this.sidebar_cursor = next;
    this.tui.requestRender();
  }

  private sidebar_set_cursor(idx: number): void {
    const entries = this.get_sidebar_entries();
    if (entries.length === 0) return;
    const clamped = Math.max(0, Math.min(idx, entries.length - 1));
    if (clamped === this.sidebar_cursor) return;
    this.sidebar_cursor = clamped;
    this.tui.requestRender();
  }

  private select_sidebar_entry(): void {
    const entries = this.get_sidebar_entries();
    if (entries.length === 0) return;
    const entry = entries[this.sidebar_cursor];
    if (!entry) return;

    if (entry.type === "all") {
      this.selected_collection_key = null;
    } else {
      this.selected_collection_key = entry.collection.key;
    }
    this.main_view = "overview";
    this.overview_scroll_offset = 0;
    // Clear search and preview state when switching collections
    this.search_query = "";
    this.search_results = [];
    this.search_loading = false;
    this.preview_focused = false;
    this.preview_content = [];
    this.preview_raw_lines = [];
    this.refresh();
  }

  private sync_sidebar_cursor_to_selection(): void {
    const entries = this.get_sidebar_entries();
    if (!this.selected_collection_key) {
      this.sidebar_cursor = 0; // "All"
      return;
    }
    for (let i = 0; i < entries.length; i++) {
      const e = entries[i];
      if (e.type === "collection" && e.collection.key === this.selected_collection_key) {
        this.sidebar_cursor = i;
        return;
      }
    }
    this.sidebar_cursor = 0;
  }

  // ═══════════════════════════════════════════════════════════
  // Main pane rendering
  // ═══════════════════════════════════════════════════════════

  private render_main_pane(width: number, height: number): string[] {
    if (this.main_view === "overview") return this.render_main_overview(width, height);
    if (this.main_view === "files") return this.render_main_files(width, height);
    if (this.main_view === "search") return this.render_main_search(width, height);
    // preview is rendered as part of 3-column layout in render()
    return this.render_main_overview(width, height);
  }

  private get_main_pane_label(): string {
    const name = this.selected_collection_key ?? "Overview";
    if (this.main_view === "files") return `${name} › Files`;
    if (this.main_view === "search") return `${name} › Search`;
    // preview label is built directly in render() for 3-column layout
    return name;
  }

  // ── Overview ────────────────────────────────────────────

  private render_main_overview(width: number, height: number): string[] {
    const t = this.theme;
    const snap = this.snapshot;
    const iw = width - 1; // 1 char left padding

    const content: string[] = [];
    content.push("");

    if (snap.binding_status === "unavailable") {
      if (snap.error_reason) {
        content.push(` ${t.fg("error", snap.error_reason)}`);
      }
      content.push("");
    } else if (!this.selected_collection_key) {
      // "All" selected or no collection — global health
      const icon = t.fg("accent", QMD_PANEL_ICON);
      const badge = this.status_badge(snap);
      content.push(` ${icon} ${t.fg("accent", t.bold("QMD Index"))}  ${badge}`);
      content.push("");

      // Show init prompt when this repo is not indexed
      if (snap.binding_status === "not_indexed") {
        if (snap.repo_root) {
          content.push(` ${t.fg("muted", snap.repo_root)}`);
        }
        content.push("");
        content.push(` ${t.fg("warning", "This repository is not indexed by QMD.")}`);
        content.push(
          ` ${t.fg("muted", "Press")} ${t.fg("accent", "i")} ${t.fg("muted", "to run /qmd init and onboard this repo.")}`
        );
        content.push("");
      }

      if (snap.collections.length > 0) {
        content.push(` ${t.fg("muted", `${snap.collections.length} collections`)}`);
        let total_docs = 0;
        for (const c of snap.collections) total_docs += c.doc_count;
        content.push(` ${t.fg("muted", `${total_docs} total documents`)}`);
        content.push(` ${t.fg("muted", `needs embed:`)} ${snap.needs_embedding}`);
        content.push(` ${t.fg("muted", `vector index:`)} ${snap.has_vector_index ? "✓" : "✗"}`);
      } else if (snap.binding_status !== "not_indexed") {
        content.push(` ${t.fg("muted", "No collections found.")}`);
      }
      content.push("");
    } else {
      // Specific collection selected
      content.push(...this.render_collection_info_card(snap, iw));
      content.push("");

      // Index section
      const embed_right =
        snap.needs_embedding > 0
          ? `${t.fg("warning", `${snap.needs_embedding}`)} ${t.fg("muted", "pending")} `
          : `${t.fg("dim", "0 pending")} `;
      content.push(this.section_header("Index", embed_right, iw));
      content.push("");
      content.push(`  ${t.fg("muted", "documents")}${" ".repeat(6)}${snap.total_documents}`);
      content.push(
        `  ${t.fg("muted", "vector index")}${" ".repeat(3)}${snap.has_vector_index ? "✓" : "✗"}`
      );
      content.push(`  ${t.fg("muted", "needs embed")}${" ".repeat(4)}${snap.needs_embedding}`);
      content.push(`  ${t.fg("muted", "collections")}${" ".repeat(4)}${snap.collections.length}`);
      content.push("");

      // Contexts
      if (snap.contexts.length > 0) {
        content.push(this.section_header(`Contexts (${snap.contexts.length})`, "", iw));
        content.push("");
        const max_path_len = Math.min(
          20,
          Math.max(6, ...snap.contexts.map((ctx) => ctx.path.length))
        );
        const col_w = max_path_len + 2;
        for (const ctx of snap.contexts) {
          const path_str = t.fg("accent", ctx.path.padEnd(col_w));
          const ann_max = Math.max(8, iw - col_w - 2);
          content.push(` ${path_str}${t.fg("dim", truncateToWidth(ctx.annotation, ann_max))}`);
        }
        content.push("");
      }

      // Stale
      if (snap.selected_collection_scope === "bound" && snap.stale_count > 0) {
        const stale_right = snap.supports_update_action
          ? `${t.fg("accent", "u")} ${t.fg("muted", "to update")} `
          : "";
        content.push(this.section_header(`Stale (${snap.stale_count})`, stale_right, iw));
        content.push("");
        const max_show = 10;
        const shown = snap.stale_paths.slice(0, max_show);
        for (const p of shown) {
          content.push(`  ${truncateToWidth(p, iw - 4)}`);
        }
        if (snap.stale_paths.length > max_show) {
          content.push(`  ${t.fg("dim", `… +${snap.stale_paths.length - max_show} more`)}`);
        }
        content.push("");
      }
    }

    this.overview_content_lines = content;

    // Clamp scroll
    const max_scroll = Math.max(0, content.length - height);
    this.overview_scroll_offset = Math.max(0, Math.min(this.overview_scroll_offset, max_scroll));

    const visible = content.slice(
      this.overview_scroll_offset,
      this.overview_scroll_offset + height
    );
    while (visible.length < height) {
      visible.push("");
    }

    return visible.map((line) => truncateToWidth(line, width));
  }

  // ── Files ───────────────────────────────────────────────

  private render_main_files(width: number, height: number): string[] {
    const t = this.theme;
    const snap = this.snapshot;
    const iw = width - 1;

    const can_toggle = snap.supports_file_toggling;
    const pending_count = can_toggle ? this.toggle.pending_count() : 0;

    // Header
    const header: string[] = [];
    header.push("");
    const indexed_count = snap.indexed_paths.length;
    const total_count = snap.filesystem_paths.length;
    const source_label = snap.file_paths_source === "qmd" ? "qmd" : "indexed";
    const count_info = `${t.fg("accent", `${indexed_count}`)}${t.fg("dim", "/")}${t.fg("muted", `${total_count}`)} ${t.fg("dim", source_label)}`;
    if (pending_count > 0) {
      const pending_info = `${t.fg("warning", `${pending_count} pending`)}`;
      header.push(` ${count_info}  ${pending_info}`);
    } else {
      header.push(` ${count_info}`);
    }
    header.push(t.fg("dim", "─".repeat(iw)));

    // Tree area
    const tree_area_h = Math.max(1, height - header.length);

    // Ensure cursor visible
    if (this.tree_cursor < this.tree_scroll_offset) {
      this.tree_scroll_offset = this.tree_cursor;
    } else if (this.tree_cursor >= this.tree_scroll_offset + tree_area_h) {
      this.tree_scroll_offset = this.tree_cursor - tree_area_h + 1;
    }
    const max_scroll = Math.max(0, this.tree_flat.length - tree_area_h);
    this.tree_scroll_offset = Math.max(0, Math.min(this.tree_scroll_offset, max_scroll));

    const visible_entries = this.tree_flat.slice(
      this.tree_scroll_offset,
      this.tree_scroll_offset + tree_area_h
    );
    const tree_lines: string[] = [];
    for (let vi = 0; vi < visible_entries.length; vi++) {
      const entry = visible_entries[vi];
      const absolute_idx = this.tree_scroll_offset + vi;
      const is_selected = absolute_idx === this.tree_cursor;
      tree_lines.push(this.render_tree_line(entry, iw, is_selected));
    }

    while (tree_lines.length < tree_area_h) {
      tree_lines.push("");
    }

    const all_lines = [...header, ...tree_lines];
    return all_lines.slice(0, height).map((line) => truncateToWidth(line, width));
  }

  // ── Search ──────────────────────────────────────────────

  private render_main_search(width: number, height: number): string[] {
    const t = this.theme;
    const iw = width - 1;

    const lines: string[] = [];

    // Header line: Search: {collection} ─── {mode}
    const mode_color =
      this.search_mode === "hybrid" ? "accent" : this.search_mode === "vector" ? "warning" : "dim";
    const mode_label = t.fg(mode_color, this.search_mode);
    const coll_name = display_key(this.selected_collection_key ?? "", 20);
    const header_left = ` ${t.fg("muted", "Search:")} ${t.fg("accent", coll_name)} `;
    const header_right = ` ${mode_label} `;
    const header_fill = Math.max(0, iw - visibleWidth(header_left) - visibleWidth(header_right));
    lines.push(
      truncateToWidth(`${header_left}${t.fg("dim", "─".repeat(header_fill))}${header_right}`, iw)
    );

    // Input line
    const cursor_char = this.search_focus === "input" ? "█" : "";
    lines.push(truncateToWidth(` ${t.fg("accent", ">")} ${this.search_query}${cursor_char}`, iw));

    // Separator
    lines.push(t.fg("dim", "─".repeat(iw)));

    // Results area
    const results_area_h = Math.max(1, height - lines.length);

    if (this.search_loading) {
      lines.push(` ${t.fg("muted", `Searching… (${this.search_mode})`)}`);
    } else if (this.search_results.length === 0) {
      if (this.search_query.trim()) {
        lines.push(` ${t.fg("dim", "No results")}`);
      } else {
        lines.push(` ${t.fg("dim", "Type a query and press enter to search")}`);
      }
    } else {
      // Summary
      const summary = ` ${t.fg("accent", `${this.search_results.length}`)} ${t.fg("dim", `results · ${this.search_results[0]?.source ?? this.search_mode}`)}`;
      lines.push(summary);
      lines.push("");

      // Build result entries (each takes 4 lines: path+score, title, snippet, blank)
      const result_lines: Array<{ line: string; result_idx: number }> = [];
      for (let i = 0; i < this.search_results.length; i++) {
        const r = this.search_results[i];
        const is_selected = this.search_focus === "results" && i === this.search_cursor;
        const marker = is_selected ? t.fg("accent", "▸") : " ";
        const score = `${Math.round(r.score * 100)}%`;
        const path_max = iw - 6 - score.length;
        const path_display = display_key(r.display_path, Math.max(8, path_max));
        const path_vis = visibleWidth(path_display);
        const score_gap = Math.max(1, iw - 4 - path_vis - score.length);

        const path_styled = is_selected ? t.fg("accent", t.bold(path_display)) : path_display;
        result_lines.push({
          line: ` ${marker} ${path_styled}${" ".repeat(score_gap)}${t.fg("dim", score)}`,
          result_idx: i,
        });

        if (r.title) {
          result_lines.push({
            line: `   ${t.fg("muted", truncateToWidth(r.title, iw - 4))}`,
            result_idx: i,
          });
        }
        if (r.snippet) {
          const snip_lines = r.snippet.split("\n").slice(0, 2);
          for (const sl of snip_lines) {
            result_lines.push({
              line: `   ${t.fg("dim", truncateToWidth(sl, iw - 4))}`,
              result_idx: i,
            });
          }
        }
        result_lines.push({ line: "", result_idx: i });
      }

      // Scroll results
      const available = results_area_h - 2; // subtract summary + blank
      if (available > 0 && result_lines.length > available) {
        // Find the first line of the selected result
        const first_selected_line = result_lines.findIndex(
          (rl) => rl.result_idx === this.search_cursor
        );
        if (first_selected_line >= 0) {
          if (first_selected_line < this.search_scroll_offset) {
            this.search_scroll_offset = first_selected_line;
          } else if (first_selected_line >= this.search_scroll_offset + available) {
            this.search_scroll_offset = first_selected_line - available + 4; // show a few lines of context
          }
        }
        this.search_scroll_offset = Math.max(
          0,
          Math.min(this.search_scroll_offset, result_lines.length - available)
        );
        const visible_result_lines = result_lines.slice(
          this.search_scroll_offset,
          this.search_scroll_offset + available
        );
        for (const rl of visible_result_lines) {
          lines.push(truncateToWidth(rl.line, iw));
        }
      } else {
        for (const rl of result_lines.slice(0, available > 0 ? available : result_lines.length)) {
          lines.push(truncateToWidth(rl.line, iw));
        }
      }
    }

    // Pad to height
    while (lines.length < height) {
      lines.push("");
    }

    return lines.slice(0, height).map((line) => truncateToWidth(line, width));
  }

  // ── Updating view ───────────────────────────────────────

  private render_updating_view(width: number): string[] {
    const t = this.theme;
    const w = Math.max(30, width);
    const iw = w - 2;
    const snap = this.snapshot;

    const content: string[] = [];
    content.push("");

    const icon = t.fg("accent", QMD_PANEL_ICON);
    const title = ` ${icon} ${t.fg("accent", t.bold("QMD Index"))}`;
    const badge = t.fg("warning", "updating…");
    const gap = Math.max(1, iw - visibleWidth(title) - visibleWidth(badge) - 1);
    content.push(`${title}${" ".repeat(gap)}${badge} `);
    content.push("");

    const upd_key = display_key(snap.collection_key ?? "—", 40);
    content.push(`  ${t.fg("accent", upd_key)}`);
    const upd_meta = [snap.glob_pattern, `${snap.total_documents} docs`]
      .filter(Boolean)
      .join(" · ");
    content.push(`  ${t.fg("dim", upd_meta)}`);

    if (this.update_progress) {
      content.push(`  ${t.fg("muted", this.update_progress)}`);
    } else {
      content.push(`  ${t.fg("muted", "indexing…")}`);
    }

    content.push("");

    const footer: string[] = [];
    footer.push(t.fg("dim", "─".repeat(iw)));
    footer.push(`  ${t.fg("accent", "esc")} cancel`);

    return this.frame_single_content([...content, ...footer], w, iw);
  }

  // ═══════════════════════════════════════════════════════════
  // Footer
  // ═══════════════════════════════════════════════════════════

  private render_footer(_inner_w: number): string {
    const t = this.theme;
    const hints: string[] = [];

    if (this.focused_pane === "sidebar") {
      hints.push(`${t.fg("accent", "→/l")} detail`);
      hints.push(`${t.fg("accent", "/")} filter`);
      hints.push(`${t.fg("accent", "j/k")} nav`);
      if (this.snapshot.supports_update_action) hints.push(`${t.fg("accent", "u")} update`);
      if (this.snapshot.binding_status === "not_indexed") hints.push(`${t.fg("accent", "i")} init`);
    } else if (this.main_view === "overview") {
      hints.push(`${t.fg("accent", "←/h")} collections`);
      if (this.selected_collection_key && this.snapshot.filesystem_paths.length > 0) {
        hints.push(`${t.fg("accent", "f")} files`);
      }
      if (this.selected_collection_key) {
        hints.push(`${t.fg("accent", "s")} search`);
      }
      if (this.snapshot.supports_update_action) hints.push(`${t.fg("accent", "u")} update`);
      if (this.snapshot.binding_status === "not_indexed") hints.push(`${t.fg("accent", "i")} init`);
      hints.push(`${t.fg("accent", "r")} refresh`);
    } else if (this.main_view === "files") {
      hints.push(`${t.fg("accent", "←/h")} collections`);
      if (this.snapshot.supports_file_toggling) hints.push(`${t.fg("accent", "space")} toggle`);
      if (this.toggle.has_pending()) hints.push(`${t.fg("accent", "a")} apply`);
      hints.push(`${t.fg("accent", "enter")} expand`);
      hints.push(`${t.fg("accent", "esc")} back`);
    } else if (this.main_view === "preview") {
      if (this.preview_focused) {
        hints.push(`${t.fg("accent", "←/h")} results`);
        hints.push(`${t.fg("accent", "j/k")} scroll`);
        hints.push(`${t.fg("accent", "g/G")} top/bottom`);
        hints.push(`${t.fg("accent", "y")} copy path`);
        hints.push(`${t.fg("accent", "esc")} results`);
      } else if (this.search_focus === "input") {
        hints.push(`${t.fg("accent", "←")} collections`);
        hints.push(`${t.fg("accent", "ctrl+t")} mode`);
        hints.push(`${t.fg("accent", "enter")} search`);
        hints.push(`${t.fg("accent", "esc")} close preview`);
      } else {
        hints.push(`${t.fg("accent", "←/h")} collections`);
        hints.push(`${t.fg("accent", "j/k")} nav`);
        hints.push(`${t.fg("accent", "→/l")} preview`);
        hints.push(`${t.fg("accent", "y")} copy path`);
        hints.push(`${t.fg("accent", "esc")} input`);
      }
    } else if (this.main_view === "search") {
      if (this.search_focus === "input") {
        hints.push(`${t.fg("accent", "←")} collections`);
        hints.push(`${t.fg("accent", "ctrl+t")} mode`);
        hints.push(`${t.fg("accent", "enter")} search`);
        hints.push(`${t.fg("accent", "esc")} back`);
      } else {
        hints.push(`${t.fg("accent", "←/h")} collections`);
        hints.push(`${t.fg("accent", "j/k")} nav`);
        hints.push(`${t.fg("accent", "enter")} preview`);
        hints.push(`${t.fg("accent", "y")} copy path`);
        hints.push(`${t.fg("accent", "esc")} input`);
      }
    }

    const hint_text = ` ${hints.join(t.fg("dim", " · "))}`;
    return hint_text;
  }

  // ═══════════════════════════════════════════════════════════
  // Tree helpers
  // ═══════════════════════════════════════════════════════════

  private open_tree_view(): void {
    this.toggle = new ToggleState(this.snapshot.indexed_paths);
    this.tree_roots = build_file_tree(this.snapshot.filesystem_paths, this.toggle.indexed_set);
    this.tree_collapsed = new Set();
    for (const root of this.tree_roots) {
      if (root.is_dir) {
        this.tree_collapsed.add(root.path);
      }
    }
    this.tree_flat = flatten_tree(this.tree_roots, this.tree_collapsed);
    this.tree_cursor = 0;
    this.tree_scroll_offset = 0;
  }

  private rebuild_tree_flat(): void {
    this.tree_flat = flatten_tree(this.tree_roots, this.tree_collapsed);
    if (this.tree_cursor >= this.tree_flat.length) {
      this.tree_cursor = Math.max(0, this.tree_flat.length - 1);
    }
  }

  private tree_toggle_expand(): void {
    if (this.tree_flat.length === 0) return;
    const entry = this.tree_flat[this.tree_cursor];
    if (!entry.node.is_dir) return;
    if (this.tree_collapsed.has(entry.node.path)) {
      this.tree_collapsed.delete(entry.node.path);
    } else {
      this.tree_collapsed.add(entry.node.path);
    }
    this.rebuild_tree_flat();
    this.tui.requestRender();
  }

  private tree_toggle_inclusion(): void {
    if (this.tree_flat.length === 0) return;
    const entry = this.tree_flat[this.tree_cursor];
    this.toggle.toggle_node(entry.node);
    this.tui.requestRender();
  }

  private async apply_pending_changes(): Promise<void> {
    if (this.updating || !this.snapshot.supports_file_toggling) return;
    const adds = [...this.toggle.pending_adds];
    const removes = [...this.toggle.pending_removes];
    if (adds.length === 0 && removes.length === 0) return;

    this.updating = true;
    this.update_progress = `${removes.length} to remove, ${adds.length} to add…`;
    this.tui.requestRender();

    try {
      await this.callbacks.on_toggle_files(adds, removes);
      this.snapshot = await this.callbacks.get_snapshot(this.selected_collection_key ?? undefined);
      this.selected_collection_key = this.snapshot.collection_key;
      this.toggle = new ToggleState(this.snapshot.indexed_paths);
      this.tree_roots = build_file_tree(this.snapshot.filesystem_paths, this.toggle.indexed_set);
      this.rebuild_tree_flat();
    } catch {
      // stay in files view
    } finally {
      this.updating = false;
      this.update_progress = null;
      this.tui.requestRender();
    }
  }

  private tree_move_cursor(delta: number): void {
    if (this.tree_flat.length === 0) return;
    const new_idx = Math.max(0, Math.min(this.tree_cursor + delta, this.tree_flat.length - 1));
    if (new_idx === this.tree_cursor) return;
    this.tree_cursor = new_idx;
    this.tui.requestRender();
  }

  private tree_set_cursor(idx: number): void {
    if (this.tree_flat.length === 0) return;
    const clamped = Math.max(0, Math.min(idx, this.tree_flat.length - 1));
    if (clamped === this.tree_cursor) return;
    this.tree_cursor = clamped;
    this.tui.requestRender();
  }

  // ═══════════════════════════════════════════════════════════
  // Preview
  // ═══════════════════════════════════════════════════════════

  private async open_preview(result: QmdSearchResult, focus_preview = true): Promise<void> {
    const gen = ++this.preview_generation;
    this.preview_loading = true;
    this.preview_path = result.display_path;
    this.main_view = "preview";
    if (focus_preview) this.preview_focused = true;
    this.tui.requestRender();

    try {
      const doc = await this.callbacks.on_get_document(result.file);
      if (gen !== this.preview_generation) return; // stale request
      if (!doc) {
        this.preview_raw_lines = ["", " Document not found."];
        this.preview_content = this.preview_raw_lines;
        this.preview_target_line = 0;
      } else {
        this.preview_raw_lines = doc.content.split("\n");
        this.preview_target_line = this.find_match_line(
          this.preview_raw_lines,
          result.snippet,
          this.search_query
        );
        this.preview_content = this.render_markdown_lines(this.preview_raw_lines);
      }
    } catch {
      if (gen !== this.preview_generation) return;
      this.preview_raw_lines = ["", " Failed to load document."];
      this.preview_content = this.preview_raw_lines;
      this.preview_target_line = 0;
    }

    this.preview_loading = false;
    this.preview_scroll_offset = Math.max(0, this.preview_target_line - 5);
    this.tui.requestRender();
  }

  private find_match_line(lines: string[], snippet: string, query: string): number {
    if (snippet) {
      const clean = snippet.replace(/^…/, "").replace(/…$/, "").trim();
      const first_line = clean.split("\n")[0]?.trim();
      if (first_line && first_line.length > 10) {
        for (let i = 0; i < lines.length; i++) {
          if (lines[i].includes(first_line)) return i;
        }
        const short = first_line.slice(0, 40);
        for (let i = 0; i < lines.length; i++) {
          if (lines[i].includes(short)) return i;
        }
      }
    }

    if (query) {
      const terms = query
        .toLowerCase()
        .split(/\s+/)
        .filter((t) => t.length > 2);
      if (terms.length > 0) {
        let best_line = 0;
        let best_score = 0;
        for (let i = 0; i < lines.length; i++) {
          const lower = lines[i].toLowerCase();
          let score = 0;
          for (const term of terms) {
            if (lower.includes(term)) score++;
          }
          if (score > best_score) {
            best_score = score;
            best_line = i;
          }
        }
        if (best_score > 0) return best_line;
      }
    }

    return 0;
  }

  private render_markdown_lines(raw_lines: string[]): string[] {
    const t = this.theme;
    const styled: string[] = [];
    let in_code_block = false;
    let code_lang = "";

    for (const line of raw_lines) {
      if (line.trimStart().startsWith("```")) {
        in_code_block = !in_code_block;
        if (in_code_block) {
          code_lang = line.trimStart().slice(3).trim();
          styled.push(t.fg("dim", ` ${"─".repeat(3)} ${code_lang || "code"} ${"─".repeat(10)}`));
        } else {
          styled.push(t.fg("dim", ` ${"─".repeat(16)}`));
          code_lang = "";
        }
        continue;
      }

      if (in_code_block) {
        styled.push(` ${t.fg("muted", line)}`);
        continue;
      }

      const h1 = line.match(/^# (.+)/);
      if (h1) {
        styled.push(` ${t.fg("accent", t.bold(h1[1]))}`);
        continue;
      }
      const h2 = line.match(/^## (.+)/);
      if (h2) {
        styled.push(` ${t.fg("accent", h2[1])}`);
        continue;
      }
      const h3 = line.match(/^### (.+)/);
      if (h3) {
        styled.push(` ${t.fg("warning", h3[1])}`);
        continue;
      }
      const h4_plus = line.match(/^#{4,}\s+(.+)/);
      if (h4_plus) {
        styled.push(` ${t.fg("muted", t.bold(h4_plus[1]))}`);
        continue;
      }

      if (/^[-*_]{3,}\s*$/.test(line.trim())) {
        styled.push(t.fg("dim", " ─────────────────────"));
        continue;
      }

      const ul = line.match(/^(\s*)[*\-+]\s+(.+)/);
      if (ul) {
        const indent = ul[1];
        styled.push(` ${indent}${t.fg("accent", "•")} ${this.style_inline_markdown(ul[2])}`);
        continue;
      }

      const ol = line.match(/^(\s*)(\d+)\.\s+(.+)/);
      if (ol) {
        const indent = ol[1];
        styled.push(` ${indent}${t.fg("dim", `${ol[2]}.`)} ${this.style_inline_markdown(ol[3])}`);
        continue;
      }

      if (line.trimStart().startsWith("> ")) {
        const content = line.replace(/^\s*>\s?/, "");
        styled.push(` ${t.fg("dim", "│")} ${t.fg("muted", content)}`);
        continue;
      }

      if (line.trim() === "") {
        styled.push("");
        continue;
      }

      styled.push(` ${this.style_inline_markdown(line)}`);
    }

    return styled;
  }

  private style_inline_markdown(text: string): string {
    const t = this.theme;

    let result = text.replace(/`([^`]+)`/g, (_match, code: string) => t.fg("muted", code));
    result = result.replace(/\*\*([^*]+)\*\*/g, (_match, bold: string) => t.bold(bold));
    result = result.replace(/__([^_]+)__/g, (_match, bold: string) => t.bold(bold));
    result = result.replace(/\*([^*]+)\*/g, (_match, italic: string) => t.fg("dim", italic));
    result = result.replace(/_([^_]+)_/g, (_match, italic: string) => t.fg("dim", italic));
    result = result.replace(
      /\[([^\]]+)\]\(([^)]+)\)/g,
      (_match, link_text: string, url: string) =>
        `${t.fg("accent", link_text)} ${t.fg("dim", `(${url})`)}`
    );

    return result;
  }

  private render_main_preview(width: number, height: number): string[] {
    const t = this.theme;
    const iw = width - 1;

    if (this.preview_loading) {
      const lines: string[] = ["", ` ${t.fg("muted", "Loading…")}`];
      while (lines.length < height) lines.push("");
      return lines;
    }

    const content = this.preview_content;
    const total = content.length;

    const path_display = display_key(this.preview_path, iw - 20);
    const pos_info = `${this.preview_scroll_offset + 1}–${Math.min(this.preview_scroll_offset + height - 2, total)}/${total}`;
    const header_left = ` ${t.fg("accent", path_display)}`;
    const header_right = `${t.fg("dim", pos_info)} `;
    const header_gap = Math.max(1, iw - visibleWidth(header_left) - visibleWidth(header_right));
    const header = truncateToWidth(`${header_left}${" ".repeat(header_gap)}${header_right}`, iw);

    const sep = t.fg("dim", "─".repeat(iw));

    const body_h = Math.max(1, height - 2);
    const max_scroll = Math.max(0, total - body_h);
    this.preview_scroll_offset = Math.max(0, Math.min(this.preview_scroll_offset, max_scroll));

    const visible = content.slice(this.preview_scroll_offset, this.preview_scroll_offset + body_h);

    const target_in_view = this.preview_target_line - this.preview_scroll_offset;

    const body_lines: string[] = [];
    for (let i = 0; i < body_h; i++) {
      const line = visible[i] ?? "";
      if (i === target_in_view && this.preview_target_line > 0) {
        body_lines.push(truncateToWidth(`${t.fg("accent", "▸")}${line}`, iw));
      } else {
        body_lines.push(truncateToWidth(` ${line}`, iw));
      }
    }

    return [header, sep, ...body_lines].slice(0, height).map((l) => truncateToWidth(l, width));
  }

  private handle_main_preview_input(key_data: string): void {
    // Back to search results (keep preview visible in 3-col)
    if (
      matchesKey(key_data, "escape") ||
      matchesKey(key_data, "h") ||
      matchesKey(key_data, "left")
    ) {
      this.preview_focused = false;
      this.search_focus = "results";
      this.tui.requestRender();
      return;
    }

    if (matchesKey(key_data, "j") || matchesKey(key_data, "down")) {
      this.preview_scroll_offset++;
      this.tui.requestRender();
      return;
    }
    if (matchesKey(key_data, "k") || matchesKey(key_data, "up")) {
      this.preview_scroll_offset = Math.max(0, this.preview_scroll_offset - 1);
      this.tui.requestRender();
      return;
    }
    if (matchesKey(key_data, "g") || matchesKey(key_data, "home")) {
      this.preview_scroll_offset = 0;
      this.tui.requestRender();
      return;
    }
    if (matchesKey(key_data, "shift+g") || matchesKey(key_data, "end")) {
      this.preview_scroll_offset = Math.max(0, this.preview_content.length - 10);
      this.tui.requestRender();
      return;
    }
    if (matchesKey(key_data, "ctrl+d") || matchesKey(key_data, "pageDown")) {
      this.preview_scroll_offset += 20;
      this.tui.requestRender();
      return;
    }
    if (matchesKey(key_data, "ctrl+u") || matchesKey(key_data, "pageUp")) {
      this.preview_scroll_offset = Math.max(0, this.preview_scroll_offset - 20);
      this.tui.requestRender();
      return;
    }

    if (matchesKey(key_data, "y")) {
      this.copy_to_clipboard(this.preview_path);
      return;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Actions
  // ═══════════════════════════════════════════════════════════

  private async refresh(): Promise<void> {
    try {
      this.snapshot = await this.callbacks.get_snapshot(this.selected_collection_key ?? undefined);
      this.selected_collection_key = this.snapshot.collection_key;
      this.overview_scroll_offset = 0;
      if (this.main_view === "files") {
        this.toggle = new ToggleState(this.snapshot.indexed_paths);
        this.tree_roots = build_file_tree(this.snapshot.filesystem_paths, this.toggle.indexed_set);
        this.rebuild_tree_flat();
      }
      this.tui.requestRender();
    } catch {
      this.tui.requestRender();
    }
  }

  private async start_update(): Promise<void> {
    if (this.updating || !this.snapshot.supports_update_action) return;
    this.updating = true;
    this.update_progress = null;
    this.tui.requestRender();

    try {
      await this.callbacks.on_update();
      this.snapshot = await this.callbacks.get_snapshot(this.selected_collection_key ?? undefined);
      this.selected_collection_key = this.snapshot.collection_key;
      this.overview_scroll_offset = 0;
    } catch {
      // stay in current view
    } finally {
      this.updating = false;
      this.update_progress = null;
      this.tui.requestRender();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // Reusable UI components
  // ═══════════════════════════════════════════════════════════

  private status_badge(snap: QmdPanelSnapshot): string {
    const t = this.theme;
    if (snap.binding_status === "unavailable") {
      return t.fg("error", "unavailable");
    }
    if (!snap.collection_key) {
      return snap.binding_status === "not_indexed"
        ? t.fg("warning", "not indexed")
        : t.fg("dim", "no collection");
    }
    if (snap.selected_collection_scope === "external") {
      return `${t.fg("warning", "external")} ${t.fg("dim", "·")} ${t.fg("warning", "readonly")}`;
    }
    if (snap.freshness_status === "stale") {
      return `${t.fg("muted", "indexed")} ${t.fg("dim", "·")} ${t.fg("warning", `${snap.stale_count} stale`)}`;
    }
    if (snap.freshness_status === "fresh") {
      return t.fg("accent", "indexed ✓");
    }
    return `${t.fg("muted", "indexed")} ${t.fg("dim", "·")} ${t.fg("dim", "freshness ?")}`;
  }

  private render_collection_info_card(snap: QmdPanelSnapshot, iw: number): string[] {
    const t = this.theme;
    const card_cw = iw - 6;
    const card_lines: string[] = [];

    const key_display = display_key(snap.collection_key ?? "—", card_cw);
    card_lines.push(t.fg("accent", t.bold(key_display)));

    const meta_parts: string[] = [];
    if (snap.glob_pattern) meta_parts.push(t.fg("dim", snap.glob_pattern));
    meta_parts.push(`${t.fg("accent", `${snap.total_documents}`)} ${t.fg("dim", "docs")}`);
    if (snap.selected_collection_scope === "bound") {
      if (snap.freshness_status === "fresh") meta_parts.push(t.fg("accent", "fresh ✓"));
      else if (snap.freshness_status === "stale")
        meta_parts.push(t.fg("warning", `${snap.stale_count} stale`));
    }
    card_lines.push(meta_parts.join(t.fg("dim", " · ")));

    if (snap.selected_collection_scope === "bound" && snap.last_indexed_at) {
      const parts = [
        `${t.fg("muted", "indexed")} ${t.fg("dim", format_relative_time(snap.last_indexed_at))}`,
      ];
      if (snap.last_indexed_commit) parts.push(t.fg("dim", snap.last_indexed_commit.slice(0, 7)));
      card_lines.push(parts.join(t.fg("dim", " · ")));
    }
    if (snap.selected_collection_scope === "external" && snap.bound_collection_key) {
      card_lines.push(`${t.fg("muted", "bound repo")} ${t.fg("dim", snap.bound_collection_key)}`);
    }

    return this.render_card(card_lines, iw);
  }

  private render_card(card_lines: string[], iw: number, label?: string): string[] {
    const t = this.theme;
    const box_w = iw - 2;
    const content_w = box_w - 4;
    const result: string[] = [];
    const indent = "  ";

    if (label) {
      const lbl = ` ${t.fg("muted", label)} `;
      const lbl_vis = visibleWidth(lbl);
      const dashes = Math.max(0, box_w - 4 - lbl_vis);
      result.push(`${indent}${t.fg("dim", "┌─")}${lbl}${t.fg("dim", `${"─".repeat(dashes)}┐`)}`);
    } else {
      result.push(`${indent}${t.fg("dim", `┌${"─".repeat(box_w - 2)}┐`)}`);
    }

    for (const line of card_lines) {
      const padded = pad_to_width(truncateToWidth(line, content_w), content_w);
      result.push(`${indent}${t.fg("dim", "│")} ${padded} ${t.fg("dim", "│")}`);
    }

    result.push(`${indent}${t.fg("dim", `└${"─".repeat(box_w - 2)}┘`)}`);
    return result;
  }

  private section_header(label: string, right_text: string, iw: number): string {
    const t = this.theme;
    const left = `${t.fg("dim", "──")} ${t.fg("muted", label)} `;
    const right = right_text ? `${right_text}${t.fg("dim", "──")}` : "";
    const left_vis = visibleWidth(left);
    const right_vis = visibleWidth(right);
    const fill = Math.max(0, iw - left_vis - right_vis);
    return `${left}${t.fg("dim", "─".repeat(fill))}${right}`;
  }

  private render_tree_line(entry: FlatTreeEntry, iw: number, is_selected: boolean): string {
    const t = this.theme;
    const { node, depth, is_last, parent_is_last } = entry;

    let prefix = " ";
    for (let d = 0; d < depth; d++) {
      if (d < parent_is_last.length && parent_is_last[d]) {
        prefix += "   ";
      } else {
        prefix += `${t.fg("dim", "│")}  `;
      }
    }

    const connector = depth > 0 ? (is_last ? t.fg("dim", "└─ ") : t.fg("dim", "├─ ")) : "";

    let label: string;
    if (node.is_dir) {
      const is_collapsed = this.tree_collapsed.has(node.path);
      const chevron = is_collapsed ? "▸" : "▾";
      const dir_name = is_selected
        ? t.fg("accent", t.bold(`${node.name}/`))
        : t.fg("muted", `${node.name}/`);
      const count = t.fg("dim", `(${node.file_count})`);
      const ind = this.dir_indicator(node);
      label = `${t.fg(ind.color, ind.char)} ${t.fg("accent", chevron)} ${dir_name} ${count}`;
    } else {
      const ind = this.file_indicator(node.path);
      const file_name = is_selected ? t.fg("accent", node.name) : node.name;
      label = `${t.fg(ind.color, ind.char)} ${file_name}`;
    }

    const line = `${prefix}${connector}${label}`;
    const marker = is_selected ? t.fg("accent", "▸") : " ";

    return truncateToWidth(`${marker}${line}`, iw);
  }

  private file_indicator(file_path: string): { char: string; color: ThemeColor } {
    const is_pending_add = this.toggle.pending_adds.has(file_path);
    const is_pending_remove = this.toggle.pending_removes.has(file_path);
    if (is_pending_add) return { char: "◉", color: "accent" };
    if (is_pending_remove) return { char: "◎", color: "warning" };
    if (this.toggle.indexed_set.has(file_path)) return { char: "●", color: "accent" };
    return { char: "○", color: "dim" };
  }

  private dir_indicator(node: FileTreeNode): { char: string; color: ThemeColor } {
    const descendant_paths = collect_file_paths(node);
    if (descendant_paths.length === 0) return { char: "○", color: "dim" };

    let indexed_count = 0;
    let has_pending = false;
    for (const p of descendant_paths) {
      if (this.toggle.is_effectively_indexed(p)) indexed_count++;
      if (this.toggle.pending_adds.has(p) || this.toggle.pending_removes.has(p)) has_pending = true;
    }

    const color = has_pending ? "warning" : "accent";
    if (indexed_count === descendant_paths.length) return { char: "●", color };
    if (indexed_count > 0) return { char: "◐", color };
    return { char: "○", color: has_pending ? "warning" : "dim" };
  }

  // ═══════════════════════════════════════════════════════════
  // Layout helpers
  // ═══════════════════════════════════════════════════════════

  private get_max_height(): number {
    const rows = this.tui.terminal.rows || 24;
    return Math.max(12, Math.floor(rows * 0.8));
  }

  /** Frame for the single-column updating view */
  private frame_single_content(content: string[], w: number, iw: number): string[] {
    const bdr = (s: string) => this.theme.fg("borderMuted", s);
    const framed = content.map((line) => {
      const padded = pad_to_width(truncateToWidth(line, iw), iw);
      return bdr("│") + padded + bdr("│");
    });
    return [bdr(`╭${"─".repeat(iw)}╮`), ...framed, bdr(`╰${"─".repeat(iw)}╯`)].map((l) =>
      truncateToWidth(l, w)
    );
  }
}

// ── Standalone helpers ──────────────────────────────────────

function pad_to_width(value: string, width: number): string {
  const vis = visibleWidth(value);
  if (vis >= width) return truncateToWidth(value, width);
  return `${value}${" ".repeat(width - vis)}`;
}

function get_printable_char(key_data: string): string | null {
  if (key_data.length !== 1) return null;
  const char_code = key_data.charCodeAt(0);
  if (char_code < 32 || char_code > 126) return null;
  return key_data;
}

function display_key(key: string, max_width: number): string {
  if (key.length <= max_width) return key;
  if (max_width <= 3) return key.slice(0, max_width);
  return `${key.slice(0, max_width - 1)}…`;
}
