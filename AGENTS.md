# Dotfiles

Nix-managed macOS and NixOS configuration. Complete the requested local work,
including resolving failures caused by the change. Make routine decisions
autonomously; ask when an unresolved choice changes the outcome or authority.
Preserve unrelated work in the assigned checkout.

Apply explicit user instructions first, then the nearest scoped `AGENTS.md`,
then its parents. Scope follows the behavior's owner, not only the edited path:
read an owner's guide when changing its callers or deployment wiring. Keep
changing facts in their source files; this guide should route to them, not copy
their inventories.

## Boundaries

- Host activation, deployment, publication, secret rotation, and destructive
  cleanup need explicit authorization. Local edits and checks do not imply it.
- Publication follows the [main-first workflow](docs/runbooks/candidate-ci.md):
  affected local checks, a normal main push, then hosted CI. NUC rollout selects
  only green main revisions. No PR or cross-task publication slot is required.
  Respect live rules; the runbook's approved cutover is required before using
  direct-main publication where required pre-push statuses still apply.
- Use `hey` for guarded system operations: `hey re` / `hey rebuild` for Darwin,
  `hey nuc` for NUC deployment, and `hey skills-update` / `hey skills-sync` for
  catalog updates. Details: [command policy](docs/adr/0001-agent-command-policy.md).
  `hey` forwards to project-local `mise run`; equivalent mise tasks are supported.
  Run from this checkout or use `mise --cd <checkout> run <task>`.
- Load the `hey-rebuilds` skill before running `hey re` or another rebuild.
- Edit repository sources, not generated files or deployed Nix store symlinks.
  Some agent configs are intentionally writable; their scoped guides identify them.
- Keep decrypted secrets out of Git, logs, command arguments, and Nix output.
- Hermes runtime/profile behavior belongs in `agents-workspace`; this repo owns
  host deployment wiring.

## Task routes

- Issues/specs: use `br` from the repository root; see [issue tracker](docs/agents/issue-tracker.md) and [triage labels](docs/agents/triage-labels.md).
- Domain context: [CONTEXT.md](CONTEXT.md) and relevant [ADRs](docs/adr/); see [domain guidance](docs/agents/domain.md).
- Agent configuration: [config/agents](config/agents/AGENTS.md).
- Skills and selection: [skills](skills/AGENTS.md). Read matching dotfiles-only skills under `.agents/skills/` directly if the runtime does not discover that directory.
- Repository instructions belong in `AGENTS.md`, and repo-specific skills in `.agents/skills/`. Prek rejects `CLAUDE.md` files and repository `.pi/skills/` or `.claude/skills/` entries. Global runtime deployment paths are separate.
- Writing: load [unslop](skills/catalog/unslop/SKILL.md) when drafting
  user-visible prose. Distinct from `deslop`, `anti-slop`, and `no-ai-slop`.
  Pin and refresh notes: [docs/agents/unslop.md](docs/agents/unslop.md).
- Oxlint: default hook is anti-slop. Opt-in English Jev rules:
  [docs/agents/oxlint.md](docs/agents/oxlint.md).
- Packages/overlays: use their scoped guides; `pkg-list` shows harnessed units.
- Host operations: [guardrails](docs/agent-guardrails.md) and the host's scoped
  guide; [NUC runbook](docs/runbooks/deploy-nuc.md) for remote deployment.
- Multi-session handoff or landing: [workflow](AGENT_WORKFLOW.md).
- Canonical docs use seven-line YAML summaries under `docs/` for discovery.

Use the narrowest check that covers the change:

- `hey check path...` checks task-owned paths in a shared dirty checkout.
- `hey check` checks every changed path; `hey check --full` runs the portable suite.
- `hey check --platform <suite>` adds explicit host or VM validation.
- `pkg-check <unit>` checks a carried upstream package or patch against fresh source.

All `hey check` modes use a disposable snapshot without changing source or
staging. `hey check --plan` shows routing. See [validation](docs/validation.md)
for CI parity, setup, and exclusions. Read-only tasks need no completion check.
Repair task-caused failures, report unrelated or unavailable checks honestly,
and rerun checks after changing their inputs.

## Spring-cleaning history

For questions about former keybindings, tools, configuration or workflows, use the commit map below rather than assuming deleted files never existed. Distinguish historical bindings from supported ones; this history does not authorize restoring retired functionality. Current native Herdr bindings live under `config/herdr/native/`, including `keys.json` and `mods/dotfiles-prefix/`; Ghostty bindings live in `config/ghostty/keybindings.conf` and its owning module.

The seven-commit batch spans `afe25148..ef571fdd`:

- `fc20529b` canonicalizes agent context. Former `CLAUDE.md` instructions and generic upstream Claude docs were removed; repository skills moved to `.agents/skills/` with deterministic prek path guards.
- `3202af00` retires Linux desktop stacks and Meshify's NixOS fallback. Look before this commit for `config/sxhkd/sxhkdrc`, BSPWM/GNOME configuration, Rofi helpers and st wiring. Meshify hardware/storage records remain; current recovery lives under `hosts/meshify/omarchy/`.
- `a63fb771` retires legacy Herdr while preserving native Herdr. Look before it for `config/herdr/config.toml` keybindings, `workspace-manager.yml`, old plugins, Review Box adapters and the legacy Ghostty frontend. The old Pi palettes remain standalone themes.
- `e96b9dbd` retires tmux/cmux, Opensessions, Jmux, dmux and workmux, including Mac/NUC selections. Look before it for `config/tmux/config`, `config/tmux/which-key.yaml`, `modules/shell/tmux/` and session/worktree helpers. Scratchpad, daily notes and Pi worktree naming remain independent of tmux.
- `35bd0283` refreshes host setup and guarded recovery guidance, replacing obsolete README inventories and the manual Homebrew activation workaround.
- `e45864bc` archives ADE, tmux/cmux and Review Box designs under `docs/archive/workflows/`, preserving historical state/recovery evidence outside current operating guidance.
- `ef571fdd` moves root `MISSION.md`, `NOTES.md` and `RESOURCES.md` under `lessons/`.

Read a removed file from its removal commit's parent, for example `git show e96b9dbd^:config/tmux/which-key.yaml`; use `git show e96b9dbd -- <path>` for the removal rationale and diff. If commit IDs change after restacking, locate the subjects with `git log --all --oneline`. Legacy themes, including Alucard on UNAS, remain supported outside their retired desktop/tmux integrations.
