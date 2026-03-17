# QMD Panel

A split-pane TUI dashboard for inspecting and searching the QMD index. Opens as a wide overlay with a persistent collection sidebar (left) and a context-sensitive main pane (right).

## Access

| Method        | Description                              |
| ------------- | ---------------------------------------- |
| `/qmd`        | Open the panel (no args)                 |
| `/qp`         | Alias — opens the panel                  |
| `Ctrl+Alt+Q`  | Toggle the panel                         |
| `/qmd status` | Print plain-text status (unchanged)      |
| `/qmd update` | Run update from command line (unchanged) |
| `/qmd init`   | Start onboarding flow (unchanged)        |

## Layout

```
╭─ Collections ────────┬─ agents ───────────────────────────────────╮
│                       │                                            │
│  ▸ All (4)            │  ◈ agents                                  │
│    agents       ● 142 │  ┌────────────────────────────────────┐    │
│    blog           38  │  │ agents (bound) · **/*.md · 142 docs │    │
│    notes          21  │  │ fresh ✓ · indexed 2h ago · a3f91d2  │    │
│    dotfiles        7  │  └────────────────────────────────────┘    │
│                       │                                            │
│                       │  ── Index ────────────────────────────────  │
│                       │      documents     142                     │
│                       │      vector index  ✓                       │
│                       │                                            │
├───────────────────────┴────────────────────────────────────────────┤
│  tab switch · / filter · j/k nav · enter select     agents · 2/4  │
╰────────────────────────────────────────────────────────────────────╯
```

- **Width**: 90% of terminal, min 90 columns, max height 80%
- **Sidebar**: Fixed 24-char inner width. Always visible.
- **Main pane**: Fills remaining width. Three views: overview, files, search.
- **Footer**: Full width, context-sensitive shortcuts.

## Focus Model

`tab` switches focus between sidebar and main pane. The focused pane has accent-colored border labels; the unfocused pane has dim labels.

### Esc Cascade

`esc` resolves the most local state first:

1. Sidebar filter active → clear filter
2. Search with text → clear text
3. Search with empty → back to overview
4. Files view → back to overview
5. Otherwise → close panel

## Sidebar

Always shows all QMD collections:

- **All (N)**: Synthetic entry at the top. Shows global health when selected.
- **Collection entries**: Name, `●` bound marker, doc count (right-aligned).
- **`/`**: Enter filter mode — type to filter collections by name.
- **`j/k`**: Navigate. **`enter`**: Select collection → main pane updates.

## Main Pane Views

### Overview (default)

Shows collection details when a specific collection is selected:

- Collection info card (name, pattern, doc count, freshness)
- Index section (documents, vector index, needs embed, collections)
- Contexts section (path + annotation)
- Stale files section (bound only)

When "All" is selected: shows global index health (total docs, collections, embedding status).

### Files (`f` or `enter` from overview)

NERDTree-style collapsible file tree. Available only when a specific collection is selected.

- `space` toggles file/dir index inclusion (bound only)
- `a` applies pending changes
- `enter` expands/collapses directories
- `esc` returns to overview

### Search (`s` or `/` from overview)

Interactive search within the selected collection. Available only when a specific collection is selected.

- **Debounced lex search**: Results appear ~200ms after keystroke
- **`enter`**: Triggers full search using the active mode (lex or hybrid)
- **`ctrl+t`**: Cycles search mode between `lex` and `hybrid`
- **`tab`**: Toggles between input and results focus
- **Results**: Path + score %, title, snippet
- **`enter`/`y` on result**: Copies file path to clipboard

## Keyboard Shortcuts

### Global

| Key          | Action                                     |
| ------------ | ------------------------------------------ |
| `q`          | Close panel                                |
| `Ctrl+C`     | Close panel                                |
| `Ctrl+Alt+Q` | Toggle panel                               |
| `tab`        | Switch focus between sidebar and main pane |

### Sidebar (when focused)

| Key         | Action                      |
| ----------- | --------------------------- |
| `j/k`, `↑↓` | Navigate collections        |
| `enter`     | Select collection           |
| `/`         | Enter filter mode           |
| `g/G`       | Jump to top/bottom          |
| `u`         | Update index (bound only)   |
| `r`         | Refresh snapshot            |
| `i`         | Start init (if not indexed) |
| `esc`       | Clear filter or close panel |

### Main — Overview

| Key          | Action                    |
| ------------ | ------------------------- |
| `f`, `enter` | Open file tree            |
| `s`, `/`     | Open search               |
| `u`          | Update index (bound only) |
| `r`          | Refresh snapshot          |
| `j/k`        | Scroll content            |
| `esc`        | Switch focus to sidebar   |

### Main — Files

| Key        | Action                                 |
| ---------- | -------------------------------------- |
| `j/k`      | Navigate tree                          |
| `enter`    | Expand/collapse directory              |
| `space`    | Toggle file/dir inclusion (bound only) |
| `a`        | Apply pending changes                  |
| `esc`, `h` | Back to overview                       |

### Main — Search (input focused)

| Key      | Action                         |
| -------- | ------------------------------ |
| Type     | Debounced lex search           |
| `enter`  | Execute search (active mode)   |
| `ctrl+t` | Cycle mode (lex ↔ hybrid)     |
| `tab`    | Focus results                  |
| `ctrl+u` | Clear query                    |
| `esc`    | Clear text or back to overview |

### Main — Search (results focused)

| Key          | Action                      |
| ------------ | --------------------------- |
| `j/k`        | Navigate results            |
| `enter`, `y` | Copy file path to clipboard |
| `tab`, `esc` | Focus input                 |

## File Tree

Same NERDTree-style tree as before. See the index toggle indicators table:

| Indicator | Meaning                        |
| --------- | ------------------------------ |
| `●`       | Indexed, no pending change     |
| `○`       | Not indexed, no pending change |
| `◉`       | Pending add                    |
| `◎`       | Pending remove                 |

Directories show aggregate indicators: `●` all, `◐` some, `○` none.

## Data Flow

```
detect_repo_binding() + check_freshness()
        ↓
build_qmd_panel_snapshot()  →  QmdPanelSnapshot
        ↓
QmdPanel.render()  →  split-pane TUI (sidebar + main)
        ↓
callbacks: get_snapshot, on_update, on_search_lex, on_search_hybrid, ...
```

The snapshot is a flat struct. Search callbacks are wired in `command.ts` and delegate to `qmd-store.ts` SDK wrappers.

## Non-TUI Fallback

When `ctx.hasUI` is false, `/qmd` prints a plain-text summary via `build_plain_text_summary()`.
