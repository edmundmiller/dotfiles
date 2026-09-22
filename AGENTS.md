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
- Use `hey` for guarded system operations: `hey re` / `hey rebuild` for Darwin,
  `hey nuc` for NUC deployment, and `hey skills-update` / `hey skills-sync` for
  catalog updates. Details: [command policy](docs/adr/0001-agent-command-policy.md).
- Edit repository sources, not generated files or deployed Nix store symlinks.
  Some agent configs are intentionally writable; their scoped guides identify them.
- Keep decrypted secrets out of Git, logs, command arguments, and Nix output.
- Hermes runtime/profile behavior belongs in `agents-workspace`; this repo owns
  host deployment wiring.

## Task routes

- Agent configuration: [config/agents](config/agents/AGENTS.md).
- Skills and selection: [skills](skills/AGENTS.md).
- Writing: load [unslop](skills/catalog/unslop/SKILL.md) when drafting
  user-visible prose. Distinct from `deslop`, `anti-slop`, and `no-ai-slop`.
  Pin and refresh notes: [docs/agents/unslop.md](docs/agents/unslop.md).
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
