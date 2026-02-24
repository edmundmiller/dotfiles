# MacTraitor-Pro (Personal Mac)

Primary personal development machine running nix-darwin.

## Key Info

- **User**: `emiller` (DO NOT change — see `hosts/AGENTS.md`)
- **Rebuild**: `hey re` from dotfiles root
- **Rollback**: `hey rollback`

## Enabled Modules

| Category | Modules                                                                                    |
| -------- | ------------------------------------------------------------------------------------------ |
| Editors  | emacs, vim (default: nvim)                                                                 |
| Dev      | node (fnm + bun globals: zele), R, python (DISABLED — openclaw conflict, see dotfiles-c11) |
| Shell    | 1password, ai, claude, codex, opencode, pi, direnv, git, jj, tmux, zsh                     |
| Services | docker, ssh (openclaw disabled)                                                            |
| Desktop  | macos defaults, raycast, openclaw, ghostty                                                 |

## Host-Specific Config

- **nix-homebrew**: ARM + Rosetta, auto-migrate, mutable taps
- **Homebrew**: no auto-update/upgrade/cleanup on activation — see `homebrew.nix` for cask/formula list
- **Intel brew symlink removal**: activation script prevents ARM/Intel conflicts
- **duti file associations**: Zed as default text editor for all source/text files, Gapplin for SVGs
- **TouchID sudo**: `security.pam.services.sudo_local.touchIdAuth = true`
- **Passwordless darwin-rebuild**: `emiller` can `sudo darwin-rebuild` without password (agent-friendly)

## Secrets

No agenix secrets on this host (credentials in 1Password).

## Gotchas

- **Python disabled**: openclaw bundles whisper which includes Python 3.13, conflicts with python module's `withPackages` env. Track in dotfiles-c11.
- **Hey not found after rebuild**: open a new terminal to pick up `$DOTFILES_BIN`
- **Homebrew `bd` conflict**: may get brew bundle error about existing symlink — pre-existing, not blocking

## Related Files

- `default.nix` — host config
- `homebrew.nix` — casks, formulae, MAS apps
- `notes.org` — scratchpad
- `modules/desktop/macos/` — shared macOS defaults (dock, finder, trackpad, Siri off, etc.)
- `hosts/AGENTS.md` — cross-host rules (usernames, secrets)
