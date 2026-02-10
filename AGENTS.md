# Agent Instructions

This is a nix-darwin dotfiles repo. Config files (lazygit, ghostty, etc.) are symlinked from the Nix store — they're **read-only**. Edit source files here, then rebuild.

## Rebuilding the System

After changing any `.nix` file or Nix-managed config:

```bash
cd ~/.config/dotfiles
sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .
```

NOPASSWD is configured — this works non-interactively. Always use the full path.

## Key Paths

- **Host config:** `hosts/mactraitorpro/default.nix`
- **Modules:** `modules/` (shell, editors, services, etc.)
- **Home-manager configs:** `config/` (lazygit, ghostty, etc.)
- **Skills catalog:** `skills/flake.nix` (child flake managing agent skills — see `skills/AGENTS.md`)
- **`darwin.nix` is NOT imported** — don't put config there

**⚠️ Child Flake Rule:** After changing `skills/flake.nix` or `skills/flake.lock`, ALWAYS run `nix flake update skills-catalog` from repo root to sync parent lock. Forgetting breaks rebuild.

## Issue Tracking

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**

- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
