# OMP Message Queue Behavior

Three independent knobs govern what happens to messages you type while OMP is
working. They answer _different_ questions about the same queue, so they don't
collapse into one setting. Set via `omp config set <key> <value>` (OMP-owned
mutable state in `~/.omp/agent/config.yml`; not Nix-managed).

## The three knobs

| Key             | Question                                                  | Values                           | Applies to    |
| --------------- | --------------------------------------------------------- | -------------------------------- | ------------- |
| `interruptMode` | _When_ is a mid-session message delivered?                | `immediate` (default), `wait`    | steering only |
| `steeringMode`  | _How many_ mid-session messages drain per delivery?       | `one-at-a-time` (default), `all` | steering      |
| `followUpMode`  | _How many_ post-turn messages does the next turn pick up? | `one-at-a-time` (default), `all` | follow-ups    |

- **interruptMode** — `immediate` cuts the in-flight tool call short to deliver
  steering; `wait` defers until the tool returns.
- **steeringMode** — how the queue of steering messages typed _during_ a turn drains.
- **followUpMode** — how the queue of messages typed _after_ a turn yields drains.

## Flow

```mermaid
graph TD
  A[you type while agent works] --> B{interruptMode}
  B -->|immediate| C[cut current tool call now]
  B -->|wait| D[hold until tool returns]
  C --> E{steeringMode}
  D --> E
  E -->|one-at-a-time| F[deliver 1 msg]
  E -->|all| G[deliver whole queue]
  H[turn yields, follow-ups queued] --> I{followUpMode}
  I -->|one-at-a-time| J[next turn takes 1]
  I -->|all| K[next turn takes all]
```

## Current config (2026-07-02)

`interruptMode: wait` + `steeringMode: all` + `followUpMode: all` — never
interrupt a running tool, but once delivery is safe, take everything queued at
once. Coherent batch-style config.

## Model roles (2026-07-02)

```
default openai-codex/gpt-5.5:medium    # newest general Codex, balanced
smol    openai-codex/gpt-5.4-mini      # cheapest *usable* Codex
slow    openai-codex/gpt-5.5:xhigh     # deepest thinking, direct sub
plan    openai-codex/gpt-5.5:high      # same model, high thinking
commit  openai-codex/gpt-5.4-mini      # cheap/fast commit messages
```

Direct-login providers (Codex on ChatGPT sub, xai-oauth) beat kilo credits for
the same model. All roles now route through the direct Codex login; kilo/Claude
is kept only as a fallback.

**Gotcha — Codex catalog lies.** `omp models openai-codex` lists 16 ids, but a
**ChatGPT-account** Codex login only permits the current generation. Every
older id (`gpt-5.3-codex`, `gpt-5.4-nano`, anything ≤5.2) returns _"not
supported when using Codex with a ChatGPT account."_ Verified-usable set:
`gpt-5.5`, `gpt-5.4`, `gpt-5.4-mini`, `gpt-5.3-codex-spark`. Always smoke-test
(`omp -p --model <id> --no-tools --no-session "say ok"`) before trusting a
catalog id.

---

## Theme notes

### Light-mode mermaid label bug (fixed 2026-07-02)

**Symptom:** In light mode, mermaid diagram node/edge labels rendered
near-invisible (light-gray on light background); prose + arrows stayed readable.

**Cause:** `theme.light` was the generic `light` theme, whose node-label color
resolves to `lightGray #b0b0b0` — washed out on the light card background. The
terminal (ghostty) runs Catppuccin Latte in light mode, so the palettes were
also mismatched.

**Fix:** `theme.light = light-catppuccin` (matches ghostty's Latte background).

**Fallback if labels still wash out:** set `tui.renderMermaid: false` — the raw
` ```mermaid ` fenced block then prints in normal prose color (always
readable, no box-art).

**Upstream:** the default `light` theme shipping invisible mermaid labels
(`#b0b0b0`) is an accessibility bug worth reporting to `can1357`
(github.com/can1357/oh-my-pi).

### Light theme catalog

omp ships ~40 light themes (set `theme.light` to any of these ids):
`light-arctic`, `light-aurora-day`, `light-canyon`, `light-catppuccin`,
`light-cirrus`, `light-coral`, `light-cyberpunk`, `light-dawn`, `light-dunes`,
`light-eucalyptus`, `light-forest`, `light-frost`, `light-github`,
`light-glacier`, `light-gruvbox`, `light-haze`, `light-honeycomb`,
`light-lagoon`, `light-lavender`, `light-meadow`, `light-mint`,
`light-monochrome`, `light-ocean`, `light-one`, `light-opal`, `light-orchard`,
`light-paper`, `light-poimandres`, `light-prism`, `light-retro`, `light-sand`,
`light-savanna`, `light-solarized`, `light-soleil`, `light-sunset`,
`light-synthwave`, `light-tokyo-night`, `light-wetland`, `light-zenith`, plus
the neutral `light`. (`omp config set theme.light <id>` — no validation, so
spelling matters.)

### Herdr alignment (done 2026-07-02)

OMP now matches Herdr and ghostty on Catppuccin, both modes:

- `theme.dark = dark-catppuccin` (Mocha — `base #1e1e2e` / `text #cdd6f4`).
  Matches Herdr's hunk plugin (`catppuccin-mocha`) and ghostty dark.
- `theme.light = light-catppuccin` (Latte). Matches Herdr's `catppuccin-latte`
  and ghostty light.

Herdr's own UI theme is `name = "terminal"` (inherits the terminal palette),
and its dev-layout maps macOS dark→mocha / light→latte
(`config/herdr/plugins/dotfiles-dev-layout/`).
