# Seqeratop (Work Mac)

Work development machine running nix-darwin. Seqera corporate laptop.

## Key Info

- **User**: `edmundmiller` (DO NOT change — corporate naming, see `hosts/AGENTS.md`)
- **Rebuild**: `hey re` from dotfiles root
- **Rollback**: `hey rollback`

## Enabled Modules

| Category | Modules                                                                    |
| -------- | -------------------------------------------------------------------------- |
| Editors  | emacs, vim (default: nvim)                                                 |
| Dev      | node (fnm), python + conda, R                                              |
| Shell    | 1password, ai, claude, codex, opencode, pi, direnv, git, jj, tmux, wt, zsh |
| Services | docker, ssh                                                                |
| Desktop  | macos defaults, ghostty                                                    |

## Host-Specific Config

- **nix-homebrew**: ARM + Rosetta, auto-migrate, mutable taps
- **Homebrew**: see `homebrew.nix` for cask/formula list
- **primaryUser**: `edmundmiller` (overrides default)

## Differences from MacTraitor-Pro

| Feature              | MacTraitor-Pro | Seqeratop      |
| -------------------- | -------------- | -------------- |
| User                 | `emiller`      | `edmundmiller` |
| Python/conda         | disabled       | enabled        |
| Raycast              | yes            | no             |
| OpenClaw             | yes            | no             |
| duti file assoc      | yes (Zed)      | no             |
| TouchID sudo         | yes            | no             |
| Passwordless rebuild | yes            | no             |

## Secrets

No agenix secrets on this host (credentials in 1Password / work SSO).

## Gotchas

- **Username is `edmundmiller`** — many paths differ from mactraitorpro. Don't assume `emiller`.
- **No passwordless sudo** — `darwin-rebuild` requires password. Agents can't auto-rebuild.

## Related Files

- `default.nix` — host config
- `homebrew.nix` — casks, formulae, MAS apps
- `modules/desktop/macos/` — shared macOS defaults (dock, finder, trackpad, Siri off, etc.)
- `hosts/AGENTS.md` — cross-host rules (usernames, secrets)
