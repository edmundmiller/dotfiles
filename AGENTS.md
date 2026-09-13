# Dotfiles

Nix-managed macOS and NixOS configuration. Complete the requested local work,
including resolving failures caused by the change. Make routine decisions
autonomously; ask when an unresolved choice changes the outcome or authority.
Preserve unrelated work in the assigned checkout.

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
- Packages/overlays: `pkg-list`, then `pkg-check <unit>` for upstream patch checks.
- Host operations: [guardrails](docs/agent-guardrails.md) and the host's scoped
  guide; [NUC runbook](docs/runbooks/deploy-nuc.md) for remote deployment.
- Multi-session handoff or landing: [workflow](AGENT_WORKFLOW.md).
- Canonical docs use seven-line YAML summaries under `docs/` for discovery.

Run `hey check` for changed work; use `hey check path...` to select task-owned
paths in a shared dirty checkout. It checks a disposable snapshot without changing
source or staging. `hey check --plan` explains routing; `hey check --full` runs
the portable suite. Host/VM validation is explicit: `hey check --platform <suite>`.
See [validation](docs/validation.md) for CI parity and platform choices. Read-only
tasks need no completion check. Repair task-caused failures, report unrelated or
unavailable checks honestly, and rerun affected checks after changing their inputs.
