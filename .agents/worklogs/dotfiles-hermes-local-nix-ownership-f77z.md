# Worklog: dotfiles-hermes-local-nix-ownership-f77z

Status: complete

## Objective

Make laptop Hermes Nix-owned and prove canonical configuration is active through one apply-and-smoke command. Stop when binary provenance, config/profile freshness, Codex login, gateway, and Kanban dispatcher checks pass after rebuild without changing NUC ownership or exposing secrets.

## Decisions

- Work in isolated `feat/hermes-local` worktree from `origin/main`; preserve dirty main checkout.
- Prefer one authoritative Nix path over syncing two mutable installations.

## Evidence

- Audit: Codex v0.144.1 is Nix-managed and logged in through ChatGPT.
- Audit: active Hermes v0.17.0 resolved through `~/.local/bin/hermes` into mutable `~/.hermes/hermes-agent/venv`, while agents-workspace primarily deploys the NUC.
- Audit: local config/profiles were stale, local gateways stopped, and config schema valid.
- Implementation: a Darwin-only Nix module installs the agents-workspace Hermes package and profile launchers, records their exact store paths and revision, and removes only the known legacy mutable wrapper.
- Scope: excluded `scintillate`; its canonical cron requires deployment-only Telegram topic IDs.
- Package decision: use agents-workspace's upstream Hermes package. The dotfiles `llm-agents` package failed its stale patch/version check and Python 3.14 libffi; mixing package sources would recreate split ownership.
- Apply: `./bin/hey hermes-local` completed nix-darwin rebuild and activation, then isolated one smoke assertion that read only Codex stdout.
- Smoke: `./bin/hey hermes-local --smoke-only` passed binary provenance, launcher provenance, all three profile renders, profile inventory, Codex ChatGPT login, live orchestrator gateway, and Kanban dispatcher dry-run.
- Final gates: post-format `./bin/hey hermes-local --smoke-only`, `./bin/hey check`, `hey agent-audit-tests tests`, and `nix develop .#full --command ./bin/hey agent-finish --worklog ...` passed.
- Landing: feature and metadata commits pushed to `origin/feat/hermes-local`; annotated agent-work tag pushed.

## Reviews

- Plan gate attempted with Gemini; ACP returned `Authentication required`. User directed not to repair reviewer authentication on this laptop.
- Landing gate attempted with Gemini; ACP again returned `Authentication required`. User directed not to repair reviewer authentication on this laptop.
- Simplification review unavailable: OpenRouter returned insufficient credits. Manual final patch review found no removable layer without weakening the apply-and-smoke contract.

## Feedback

Current workflow permits canonical config edits without proving they reached the laptop runtime.

## Remaining work

None.

## Commits

- `b87fe7ede feat(hermes): manage laptop runtime with nix`
- `394983904 chore(agents): record Hermes rollout`
- Tag: `agent-work/dotfiles-hermes-local-nix-ownership-f77z`.
