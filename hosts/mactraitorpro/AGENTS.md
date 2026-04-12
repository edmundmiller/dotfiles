# MacTraitor-Pro (Personal Mac)

Primary personal development machine running nix-darwin.

## Key Info

- **User**: `emiller` (DO NOT change — see `hosts/AGENTS.md`)
- **Rebuild**: `hey re` from dotfiles root
- **Rollback**: `hey rollback`

## Enabled Modules

| Category | Modules                                                                                                                     |
| -------- | --------------------------------------------------------------------------------------------------------------------------- |
| Editors  | emacs, vim (default: nvim)                                                                                                  |
| Dev      | node (fnm + bun globals: hunkdiff, critique; packaged Nix zele), R, python (DISABLED — openclaw conflict, see dotfiles-c11) |
| Shell    | 1password, ai, claude, codex, opencode, pi, direnv, git, jj, tmux, zsh                                                      |
| Services | docker, ssh (openclaw disabled)                                                                                             |
| Desktop  | macos defaults, raycast, openclaw, ghostty                                                                                  |

## Host-Specific Config

- **QMD CLI**: `pkgs.llm-agents.qmd` installed system-wide for local search / parity with NUC OpenClaw memory backend; activation removes stale bun/npm `qmd` shims so the Nix binary wins
- **zele CLI**: installed system-wide as `pkgs.my.zele` (upstream source + local patch stack), not via Bun global install
- **nix-homebrew**: ARM-only (Rosetta disabled), auto-migrate, mutable taps
- **Homebrew**: no auto-update/upgrade/cleanup on activation — see `homebrew.nix` for cask/formula list
- **duti file associations**: Zed as default text editor for all source/text files, Gapplin for SVGs
- **TouchID sudo**: `security.pam.services.sudo_local.touchIdAuth = true`
- **Passwordless darwin-rebuild**: `emiller` can `sudo darwin-rebuild` without password (agent-friendly)

## Secrets

No agenix secrets on this host (credentials in 1Password).

## Gotchas

- **Python disabled**: openclaw bundles whisper which includes Python 3.13, conflicts with python module's `withPackages` env. Track in dotfiles-c11.
- **Hey not found after rebuild**: open a new terminal to pick up `$DOTFILES_BIN`

## Related Files

- `default.nix` — host config
- `homebrew.nix` — casks, formulae, MAS apps
- `notes.org` — scratchpad
- `modules/desktop/macos/` — shared macOS defaults (dock, finder, trackpad, Siri off, etc.)
- `hosts/AGENTS.md` — cross-host rules (usernames, secrets)
