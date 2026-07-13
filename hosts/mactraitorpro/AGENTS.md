---
purpose: Route MacTraitor-Pro changes to host-specific commands and ownership.
applies_to: Changes under hosts/mactraitorpro or laptop-only services.
entrypoint: Read default.nix, then use the matching host command below.
verification: Run the focused command, then hey check.
update_when: Host ownership, modules, commands, or gotchas change.
---

# MacTraitor-Pro (Personal Mac)

Primary personal development machine running nix-darwin.

## Key Info

- **User**: `emiller` (DO NOT change — see `hosts/AGENTS.md`)
- **Rebuild**: `hey re` from dotfiles root
- **Rollback**: `hey rollback`

## Enabled Modules

Read `default.nix` for the current module set, and check `../AGENTS.md` for cross-host rules before changing host modules.

## Host-Specific Config

- **QMD CLI**: `pkgs.llm-agents.qmd` installed system-wide for local search / parity with NUC OpenClaw memory backend; activation removes stale bun/npm `qmd` shims so the Nix binary wins
- **zele CLI**: installed system-wide as `pkgs.my.zele` (upstream source + local patch stack), not via Bun global install
- **nix-homebrew**: ARM-only (Rosetta disabled), auto-migrate, mutable taps
- **Homebrew**: no auto-update/upgrade/cleanup on activation — see `homebrew.nix` for cask/formula list
- **duti file associations**: Zed as default text editor for all source/text files, Gapplin for SVGs
- **TouchID sudo**: `security.pam.services.sudo_local.touchIdAuth = true`
- **Passwordless darwin-rebuild**: `emiller` can `sudo darwin-rebuild` without password (agent-friendly)
- **Hermes CLI**: Nix-managed with canonical local profiles through `modules.agents.hermes-local`; run `hey hermes-local` to rebuild and prove profile, login, gateway, and dispatcher health. NUC deployment remains separately owned.

## Secrets

No agenix secrets on this host (credentials in 1Password). The laptop Hermes CLI is Nix-managed by `modules.agents.hermes-local`; the NixOS-only `modules.agents.hermes` remains reserved for NUC deployment.

## Gotchas

- **Python disabled**: openclaw bundles whisper which includes Python 3.13, conflicts with python module's `withPackages` env. Track in dotfiles-c11.
- **Hey not found after rebuild**: open a new terminal to pick up `$DOTFILES_BIN`

## Related Files

- `default.nix` — host config
- `homebrew.nix` — casks, formulae, MAS apps
- `notes.org` — scratchpad
- `modules/desktop/macos/` — shared macOS defaults (dock, finder, trackpad, Siri off, etc.)
- `hosts/AGENTS.md` — cross-host rules (usernames, secrets)
