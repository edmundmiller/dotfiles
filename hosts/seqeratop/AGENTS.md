# Seqeratop (Work Mac)

Work development machine running nix-darwin. Seqera corporate laptop.

## Key Info

- **User**: `edmundmiller` (DO NOT change — corporate naming, see `hosts/AGENTS.md`)
- **Rebuild**: `hey re` from dotfiles root
- **Rollback**: `hey rollback`

## Enabled Modules

| Category | Modules                                                                |
| -------- | ---------------------------------------------------------------------- |
| Editors  | emacs, vim (default: nvim)                                             |
| Dev      | node (fnm), python + conda, R                                          |
| Shell    | 1password, ai, claude, codex, opencode, pi, direnv, git, jj, tmux, zsh |
| Services | docker, ssh                                                            |
| Desktop  | macos defaults, ghostty                                                |

## Host-Specific Config

- **QMD CLI**: `pkgs.llm-agents.qmd` installed system-wide for local search / parity with NUC OpenClaw memory backend
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

## Network

- **No Tailscale** — can't SSH to NUC or other Tailscale hosts from this machine.

## Gotchas

- **Username is `edmundmiller`** — many paths differ from mactraitorpro. Don't assume `emiller`.
- **No passwordless sudo** — `darwin-rebuild` requires password. Use `tmux-bash` to launch rebuild so the user can enter their password in the tmux pane:
  ```
  tmux-bash name=rebuild command="cd ~/.config/dotfiles && sudo darwin-rebuild switch --flake ."
  ```
- **Hostname is `L19W56QXR4`** — flake attribute is `Seqeratop` (capitalized), but the actual hostname differs. `darwin-rebuild switch --flake .` auto-resolves by hostname and fails. Use `--flake .#Seqeratop` explicitly.

## Related Files

- `default.nix` — host config
- `homebrew.nix` — casks, formulae, MAS apps
- `modules/desktop/macos/` — shared macOS defaults (dock, finder, trackpad, Siri off, etc.)
- `hosts/AGENTS.md` — cross-host rules (usernames, secrets)
