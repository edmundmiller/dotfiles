# ADR 0008: Treat terminal theming as a layered stack

## Status

Proposed

## Date

2026-06-21

## Context

The current Ghostty + Herdr workflow can show multiple terminal UIs at once:
Herdr owns the workspace chrome, then each pane runs a child program such as Pi,
Hunk, Neovim, or a shell. These programs do not share one theme engine. They
render into the same Ghostty terminal grid, but each layer decides its own
colors.

The observed failure mode on MacTraitor-Pro was mixed polarity in one Herdr
workspace:

- Ghostty window and Herdr chrome are dark.
- Pi is dark, but muted text is low-contrast.
- Hunk is light inside a dark Herdr/Ghostty frame.
- Neovim is explicitly dark via `tokyonight-night`.

This looks like "Ghostty bleeding through" because Herdr and child TUIs often
use transparent or terminal-default backgrounds. In practice, there are two
independent effects:

1. A child app can intentionally leave regions transparent/reset, exposing the
   terminal or Herdr background.
2. A child app can choose the wrong light/dark palette and paint its own
   background, as Hunk currently appears to do in the screenshot.

## Render call stack

```text
macOS appearance
  -> Ghostty config/theme
    -> terminal background, foreground, palette, window theme
      -> Herdr server/client config
        -> Herdr chrome: sidebar, tabs, borders, pane focus, custom theme
          -> pane child process
            -> Pi theme, Hunk theme, Neovim colorscheme, shell prompt, etc.
```

## Config ownership stack

```text
hosts/<host>/default.nix
  -> modules/desktop/term/ghostty/default.nix
    -> config/ghostty/config + ui.conf + themes/*

hosts/<host>/default.nix
  -> modules/shell/herdr/default.nix
    -> config/herdr/config.toml
    -> ~/.config/herdr/config.toml
    -> ~/.pi/agent/themes/<dotfiles-herdr*.json>

modules/agents/pi/lib/_settings.nix
  -> ~/.pi/agent/settings.json
    -> theme = light/<herdrThemeName>
    -> themes = [ ~/.pi/agent/themes/<herdrThemeName>.json ]

modules/shell/git/default.nix
  -> config/hunk/config.toml
    -> theme = "auto"
    -> mode = "auto"

config/nvim/lua/kickstart/plugins/tokyonight.lua
  -> vim.cmd.colorscheme "tokyonight-night"
```

## Current repo facts

MacTraitor-Pro target:

- `hosts/mactraitorpro/default.nix` enables Ghostty, Herdr, Pi, Hunk, and Neovim.
- Ghostty and Stylix use Catppuccin (`Latte`/`Mocha` at the terminal boundary,
  `catppuccin-mocha` for the host Stylix base).
- Herdr uses terminal-derived chrome instead of hard-coded Latte colors.
- Pi keeps the source `theme = "terminal"` instead of being forced to
  `light/dotfiles-herdr`.
- Ghostty uses `theme = light:Catppuccin Latte,dark:Catppuccin Mocha`.
- Hunk config keeps `theme = "auto"` as a generic fallback, but the Herdr
  launcher overrides it because Hunk `auto` chooses GitHub light/dark themes,
  not Catppuccin.
- Hunk must paint its own themed background; transparent backgrounds let a
  lighter terminal surface show through inside dark Herdr/Ghostty chrome.
- Herdr-launched Hunk sessions pass `--theme catppuccin-mocha` or
  `--theme catppuccin-latte` from macOS appearance, plus `--no-transparent-bg`.
- Neovim loads `tokyonight-night`.

Seqeratop:

- `hosts/seqeratop/default.nix` opts Herdr/Pi into the `seqera` variants.
- Stylix drives terminal/editor colors from `themes/seqera-dark.yaml`.
- Seqera Ghostty theme files are linked into `~/.config/ghostty/themes`.

Shared gotcha:

- `config/ghostty/themes/SeqeraDark` and `SeqeraLight` are only usable by name
  on hosts that link them into `~/.config/ghostty/themes`, or when referenced by
  absolute path.

## Layer responsibilities

Ghostty is the terminal substrate.

- It owns the first visible background and ANSI palette.
- It supports `light:...,dark:...` themes based on desktop appearance.
- It searches custom theme names in `~/.config/ghostty/themes` and its resource
  themes directory.
- It should not be treated as proof that child TUIs will choose matching
  light/dark palettes.

Herdr is the workspace chrome.

- It reads `~/.config/herdr/config.toml`.
- It owns sidebar, tabs, pane borders, focus state, and custom theme slots.
- Its `panel_bg = "reset"` means parts of the UI may expose the terminal
  background.
- It launches panes; it does not force child app themes.

Pi is a child full-screen TUI.

- It loads theme resources from `settings.json` `themes`.
- This repo can inject a Herdr-matching Pi theme when Herdr is enabled.
- MacTraitor-Pro opts out of that injection so Pi can use the terminal-oriented
  theme from `config/pi/settings.jsonc`.

Hunk is a child full-screen review TUI.

- It is a review-first terminal diff viewer built on OpenTUI and Pierre diffs.
- This repo sets Hunk to `theme = "auto"` and `transparent_background = false`
  as the baseline, but does not rely on `auto` for Catppuccin.
- The Herdr dev-layout launcher makes the review pane explicit:
  `catppuccin-mocha` in macOS dark mode and `catppuccin-latte` otherwise, with
  Hunk painting its own background.
- Hunk is the highest-priority mismatch because it paints large code review
  regions.

Neovim is a child editor TUI.

- It has its own colorscheme and background model.
- This repo explicitly loads `tokyonight-night`, so Neovim is a stable dark
  control case.

Shell/prompt output is the other useful control case.

- It mostly uses ANSI colors and transparent terminal defaults.
- If shell output looks right while Hunk looks wrong, the bug is probably Hunk's
  palette selection rather than Ghostty's base palette.

## Decision

Use an explicit layered theme contract instead of assuming one global theme.

1. Ghostty owns terminal defaults and custom theme availability.
2. Herdr owns chrome colors and may intentionally expose Ghostty via `reset`.
3. Each child TUI must select a compatible palette explicitly or have a verified
   auto mode.
4. Host-level theme variants must configure the whole stack, not only Ghostty.
5. Fixes should be validated with at least four panes: Pi, Hunk, Neovim, and a
   plain shell.

Do not make Hunk, Pi, or Neovim infer their final theme from Ghostty unless their
upstream docs and observed behavior prove that path works.

## Recommended next changes

1. Link `config/ghostty/themes/*` for any host that may name those themes.
2. Keep MacTraitor-Pro on Pi's terminal-oriented theme; do not force
   `light/dotfiles-herdr`.
3. Keep Herdr's Hunk launcher explicit; do not rely on Hunk's generic `auto`
   theme for Catppuccin.
4. Keep Neovim as a control: `tokyonight-night` should remain visually dark
   regardless of Ghostty/Herdr.
5. Add a small visual smoke checklist after rebuilds:
   - Ghostty base background
   - Herdr sidebar/tab contrast
   - Pi muted text contrast
   - Hunk diff background polarity
   - Neovim background polarity
   - Plain shell ANSI readability

## Sources reviewed

- Ghostty docs: [Color Theme](https://ghostty.org/docs/features/theme) and local
  `ghostty +show-config --default --docs`.
- Herdr docs: [Configuration](https://herdr.dev/docs/configuration/) and local
  `config/herdr/README.md`.
- Pi docs: [Settings](https://pi.dev/docs/latest/settings).
- Hunk docs: [modem-dev/hunk](https://github.com/modem-dev/hunk) and
  [automatic light/dark theme issue](https://github.com/modem-dev/hunk/issues/238).
- Neovim docs: [Usr_06](https://neovim.io/doc/user/usr_06/).
- Local config:
  - `config/ghostty/ui.conf`
  - `modules/desktop/term/ghostty/default.nix`
  - `modules/shell/herdr/default.nix`
  - `modules/agents/pi/lib/_settings.nix`
  - `config/hunk/config.toml`
  - `config/nvim/lua/kickstart/plugins/tokyonight.lua`
  - `hosts/mactraitorpro/default.nix`
  - `hosts/seqeratop/default.nix`
