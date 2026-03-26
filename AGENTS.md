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
- **OpenClaw service module:** Lives in **`openclaw-workspace`** repo (`github:edmundmiller/openclaw-workspace`) at `module/`, NOT in this repo. Imported via `inputs.openclaw-workspace.nixosModules.openclaw` in `lib/nixos.nix`. Host-specific config (secrets, telegram, cron) stays in `hosts/nuc/default.nix`. Mac remote client is at `modules/desktop/apps/openclaw/`.
- **`darwin.nix` is NOT imported** — don't put config there

**⚠️ Child Flake Rule:** After changing `skills/flake.nix` or `skills/flake.lock`, ALWAYS run `nix flake update skills-catalog` from repo root to sync parent lock. Forgetting breaks rebuild.

## Naming Conventions

| Context                        | Convention                    | Example                         |
| ------------------------------ | ----------------------------- | ------------------------------- |
| Nix variables                  | `snake_case`                  | `my_package`, `host_name`       |
| Nix functions                  | `camelCase`                   | `mkHost`, `mapModules`          |
| Nix file names                 | `kebab-case` or `default.nix` | `nix-darwin.nix`, `default.nix` |
| TypeScript functions/variables | `camelCase`                   | `fetchData`, `userName`         |
| TypeScript types/interfaces    | `PascalCase`                  | `AgentConfig`, `SkillManifest`  |
| Shell script file names        | `kebab-case`                  | `hey`, `skills-sync`            |
| Module directories             | `kebab-case`                  | `desktop-apps`, `shell`         |

## Environment Variables

This is a **Nix-managed repository** — the environment is declarative, not `.env`-based.

- **No `.env` file needed.** All dependencies are provided by Nix (`nix develop` or `nix-shell`).
- **Secrets are managed via agenix** (encrypted `.age` files in `hosts/nuc/secrets/`). Never store plaintext secrets in the repo.
- **1Password integration via opnix** — runtime secrets are read from 1Password vaults using a service account token bootstrapped at `/etc/opnix-token` (NixOS) or via `op` CLI (Darwin).
- **The `hey` CLI** (`bin/hey`) wraps common operations (rebuild, deploy, update). Use it instead of raw nix commands.
- **For development:** `nix develop` provides all tools (nixfmt, deadnix, statix, deploy-rs, pre-commit hooks). The `.envrc` activates this automatically via direnv.
- **No API keys in environment.** Agent API keys (Gemini, Linear, OpenClaw, etc.) are injected via agenix or opnix at service activation time, never exported as shell variables.

## Diff Policy

- Prefer `diffs` over `git diff` for reviews and change analysis.
- Use native `git diff` only if diffs can't express required flags/output.

## File Search

- Use the `fff` MCP tools for all file search operations instead of default search tools.

## Code Quality Checks

### Duplicate Code Detection

This repository uses **jscpd** to detect code duplication in TypeScript, JavaScript, and Nix files.

**Running manually:**

```bash
npx jscpd . --config .jscpd.json
```

**Configuration:** `.jscpd.json` (10% duplication threshold)

**Pre-commit hook:** Runs on `pre-push` stage automatically

**What it catches:**

- Copy-pasted code blocks (5+ lines, 50+ tokens)
- Similar code patterns that should be refactored into shared functions
- Repeated test setup/teardown (consider test helpers)

**Handling duplicates:**

- Review `.jscpd-report/jscpd-report.json` for details
- Refactor into shared utilities or functions
- For legitimate duplication (tests, configs), document why it's acceptable

### Dead Code Detection

**deadnix** is enabled in treefmt (`treefmt.programs.deadnix.enable = true`) and runs automatically on all Nix files during formatting. It detects unused variables, unused function arguments, and dead `let` bindings in `.nix` files.

Deadnix runs as part of `treefmt` both in the dev shell and via the `treefmt` pre-commit hook.

### Static Analysis & Complexity

**statix** is enabled in treefmt (`treefmt.programs.statix.enable = true`) and lints all Nix files for antipatterns, redundant constructs, and complexity issues (e.g., unnecessary `let` bindings, eta-reducible functions, manual `inherit` misuse). It serves as the primary complexity and code-quality checker for Nix code.

For TypeScript code in `pi-packages/` and `packages/`, complexity analysis is aspirational — consider adding ESLint complexity rules as the TS codebase grows.

### Log Scrubbing

This repo manages secrets via **agenix** (encrypted `.age` files) and **opnix** (1Password runtime injection). Follow these rules to prevent secret leakage:

- **Never log decrypted secret values.** Agenix encrypts secrets at rest — decrypted paths should be referenced but their contents never echoed or printed.
- **`.gitignore` blocks `.env` files** from being committed, preventing accidental plaintext secret commits.
- **Never `echo` or `log` secret values** in Nix expressions or shell scripts. Pass secrets by file path or environment variable reference, not by value.
- **Use `set +x` before handling secrets** in shell scripts to prevent bash trace logging from exposing secret values in CI output.
- **Home-manager managed configs are read-only symlinks** from the Nix store, reducing the risk of runtime secret leakage into mutable config files.

### Unused Dependencies Detection

**deadnix** detects unused Nix bindings (variables, function arguments, `let` bindings) and runs automatically via treefmt. See [Dead Code Detection](#dead-code-detection) above.

Additionally, **`nix flake check`** validates the flake and all its dependencies, ensuring no broken or missing inputs. The CI runs `nix build .#checks.*` which exercises these checks on every push and PR.

### Large File Detection

A pre-commit hook rejects files over 500 KB (excluding lock files and known large files). This prevents accidental commits of binaries, data dumps, or build artifacts.

### Tech Debt Tracking

A pre-commit hook scans for `TODO`, `FIXME`, and `HACK` comments and reports them on every commit. It does **not** block commits — it surfaces tech debt for awareness. Review the output periodically and file issues for high-priority items.

## Deployment

Deployment is via **deploy-rs** (see `flake.nix` `deploy.nodes`). There is no CI-driven deployment — all deploys are triggered locally.

- **Deploy to NUC:** `hey nuc` (runs `nix run .#deploy-rs -- .#nuc --skip-checks`)
- **Deploy dry-run:** `hey deploy-dry nuc`
- **After deploy to NUC:** verify via `ssh nuc "systemctl status home-assistant"` for HA, check NUC dashboard with `hey nuc-status`
- **After macOS rebuild:** verify via `nix flake check` (runs all flake checks locally)
- **Rollback:** `hey rollback` or `nix-env --rollback` for previous generation; on NUC: `hey nuc-rollback`

See [docs/runbooks/deploy-nuc.md](docs/runbooks/deploy-nuc.md) for the full deployment runbook.

## Auto-Generated Configuration

Several configurations in this repo are **auto-generated** — do not edit them by hand:

- **`.pre-commit-config.yaml`** — Generated by `git-hooks.nix`. Edit the Nix source in the flake's `checks` output, not the YAML directly.
- **Skills catalog symlinks** — Home-manager auto-generates skill symlinks from the skills child flake. Edit `skills/flake.nix` to change skills.
- **Treefmt config** — Drives formatting across all file types (Nix, TypeScript, JSON, YAML, Markdown). Configured in the flake via `treefmt-nix`.
- **Module docs** — Run `bin/generate-module-docs` to regenerate the module index.

## Issue Tracking

This project uses **bd** (beads) for issue tracking.
Run `bd prime` for workflow context, or install hooks (`bd hooks install`) for auto-injection.

**Quick reference:**

- `bd ready` - Find unblocked work
- `bd create "Title" --type task --priority 2` - Create issue
- `bd close <id>` - Complete work
- `bd sync` - Sync with git (run at session end)

For full workflow details: `bd prime`

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
