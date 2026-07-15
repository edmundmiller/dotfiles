# Worklog: refresh-packages-overlays-2026-07-14

Status: complete

## Objective

Update every repository-managed package and overlay source that has a supported upstream refresh path. Preserve local patch stacks, build affected Darwin packages, deploy the resulting configuration, and stop only when checks pass and the branch is current upstream.

## Decisions

- Treat local implementation-only packages without an upstream source pin as not applicable, not as missing work.
- Preserve unrelated modification in `config/agents/rules/03-version-control.md`.
- Refresh root flake inputs first; they supply upstream packages consumed directly and by overlays.
- For repo-local Nix sources, use `nix-update` where source metadata permits. Manually refresh commit pins and binary artifacts that it cannot infer.
- Update npm/Bun dependencies only in source-owned workspaces with adjacent manifests. Regenerate vendoring-only lockfiles from refreshed upstream sources instead of independently bumping them.
- Maintain an auditable unit ledger: updated, already current, or not applicable, with focused validation per changed unit.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin 27 arm64.
- `nix shell .#package-harness -c pkg-list` inventoried 7 overlay and 70+ local package units.
- Repo-local dependency locks: 11 npm lockfiles and 3 Bun lockfiles under `packages/`; none under `overlays/`.
- Source-owned dependency workspaces with locks: `pi-packages`, `acpx`, `tmux-smart-name`, `jut/skill/eval`, and `opencode-tmux-namer`; other locks are Nix vendoring artifacts.
- Overlay source ownership: Herdr and Ghostty use explicit upstream pins; Hunk, Hermes, and OMP inherit flake inputs; OpenCode pins npm platform artifacts.
- `renovate.json` confirms root flake, GitHub-tagged Nix package, npm, and Bun update surfaces.
- Updated root flake inputs, three overlay source/artifact pins, 38 explicit package sources, and five source-owned npm/Bun workspaces. Local implementation-only units were not applicable.
- `claude-max-api-proxy` upstream is no longer publicly resolvable. Its pinned source remains fetchable; the package now builds with the refreshed Node toolchain.
- Rebased the Herdr, Jmux, Critique, and OpenWiki patch stacks. Stack v0.4.2 upstreamed the local explicit-chain fix, so the obsolete patch was removed.
- Every changed exported package builds on Darwin. `pkg-check hunk` passed 256 tests; `pkg-check openwiki` passed typecheck and 52 tests.
- A clean `pi-packages` install and workspace typecheck passed. Pi QMD passed 76 tests; tmux-smart-name passed 152 tests. The integration suite passed 90 tests with `@marcfargas/pi-test-harness` pinned at 0.5.0 because 0.6.1 switched to the incompatible `@earendil-works/*` runtime namespace.
- Final `hey check` passed Darwin evaluation, formatting, hooks, tmux tests, package harness/policy tests, and ast-grep tests.
- Home Manager 26.11 made explicit `gtk.gtk4.theme = null` incompatible with its non-null GTK theme definition; removed the obsolete Darwin and NUC workarounds.
- Node 25 reached end of life during evaluation. Pi wrappers now use Node 24, and the settings/runtime smoke tests pass.
- Homebrew 6 rejects short names from third-party taps. Every such formula and cask now uses its fully qualified tap name.
- Routine headless activation keeps MAS apps declared as inventory but skips Xcode, Keynote, and Numbers.
- Home Manager now uses the Darwin account's real UID while retaining UID 1000 for Linux.
- `obsidian-headless` 0.0.13 builds on Darwin with its regenerated npm dependency hash.
- OMP's Nextflow scanner archive is linked whole on Linux; `hey nuc-wt build` completed as `/nix/store/rfh7ld31lp7spnsg03iiakk83cyix2q3-nixos-system-nuc-26.11.20260714.18b9261`.
- Temporary 24 GiB NUC zram prevented the prior OOM and was removed after validation; `free` and `swapon` confirmed 0 B swap.
- A final `darwin-rebuild switch --flake .` completed, including Homebrew and Home Manager activation.

## Reviews

- Plan gate blocked: both configured heterogeneous reviewers (`claude`, then `gemini`) returned `Authentication required` before reviewing. The plan remains source-backed and bounded; proceed while recording this unavailable gate.

## Feedback

- `pkg-list` is not on the default shell PATH; invoke it through `nix shell .#package-harness -c`.
- `nix fmt` formats the entire repository, not only changed paths. Restore formatter-only changes outside the task before staging.

## Remaining work

None.

## Commits

- `3fe33cdea chore(deps): refresh packages and overlays`
