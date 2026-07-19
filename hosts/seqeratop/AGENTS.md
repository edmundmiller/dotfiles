---
purpose: Route agents for the Seqeratop work nix-darwin host.
applies_to: Changes under hosts/seqeratop or Seqeratop rebuilds.
entrypoint: Read default.nix, then hey re from the repo root.
verification: hey check and sudo darwin-rebuild switch --flake .
update_when: Host modules, username, rebuild, or recovery steps change.
---

# Seqeratop (Work Mac)

Work development machine running nix-darwin. Seqera corporate laptop.

## Key Info

- **User**: `edmundmiller` (DO NOT change — corporate naming, see `hosts/AGENTS.md`)
- **Rebuild**: `hey re` from dotfiles root
- **Rollback**: `hey rollback`

## Enabled Modules

| Category | Modules                                                            |
| -------- | ------------------------------------------------------------------ |
| Editors  | emacs, vim (default: nvim)                                         |
| Dev      | node (fnm), python + conda, R                                      |
| Shell    | 1password, claude, codex, opencode, pi, direnv, git, jj, tmux, zsh |
| Services | docker, ssh                                                        |
| Desktop  | macos defaults, ghostty                                            |

## Host-Specific Config

- **QMD CLI**: `pkgs.llm-agents.qmd` installed system-wide for local search / parity with NUC OpenClaw memory backend; activation removes stale bun/npm `qmd` shims so the Nix binary wins
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
- **Hostname is `L19W56QXR4`** — `darwinConfigurations.L19W56QXR4` aliases `Seqeratop`, so bare `--flake .` resolves correctly.

## Related Files

- `default.nix` — host config
- `homebrew.nix` — casks, formulae, MAS apps
- `modules/desktop/macos/` — shared macOS defaults (dock, finder, trackpad, Siri off, etc.)
- `hosts/AGENTS.md` — cross-host rules (usernames, secrets)
