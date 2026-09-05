---
purpose: Define repository-wide safety, source ownership, and command boundaries.
applies_to: Dotfiles source changes and authorized host operations.
entrypoint: Use the subsystem router for its specific contracts.
verification: Inspect the affected artifact and run its focused check.
update_when: Shared editing, deployment, or documentation ownership changes.
---

# Agent guardrails

## Host and command boundaries

- Establish the target with `hostname` and `uname -a` before host-specific action.
  An orb or a successful local build is not the deployed host.
- Nix-managed runtime files are often store symlinks. Edit repository sources;
  generated files identify their manifest/generator. Preserve mutable runtime
  state and unrelated work.
- State-changing Nix, Darwin, NUC, skills, cleanup, and Homebrew operations use
  `hey`; [ADR 0001](adr/0001-agent-command-policy.md) owns command policy.
  Darwin activation is `hey re` / `hey rebuild`. Remote skill updates use
  `hey skills-update`; `hey skills-sync` syncs the parent and activates the host.
- Do not evaluate `nixosConfigurations.nuc` on Darwin. Use `hey nuc-wt build`
  for isolated build evidence; `hey nuc dry-activate` / `hey nuc` are target
  operations with separate authority.
- Keep decrypted agenix/opnix values out of source, output, and argv; pass
  secret paths or child-scoped environment references.
- Approval for local implementation is not approval to publish, activate hosts,
  rotate credentials, change shared infrastructure, or destroy state. Prepare
  safe reviewable work before asking for the remaining action.

## Documentation ownership

Canonical runbooks/design docs change with the contracts they describe and use
this searchable summary, closed by line seven:

```yaml
---
purpose: Why this doc exists.
applies_to: When it is relevant.
entrypoint: Owning source or first operation.
verification: Evidence for the documented contract.
update_when: Changes that invalidate it.
---
```

Short AGENTS.md scope routers need no duplicate metadata header. Keep them to
local facts, boundaries, and links; longer recipes belong in task-specific skills
or canonical runbooks. Generate drifting inventories instead of copying them.

OpenWiki pages are generated. Follow [its quickstart](../openwiki/quickstart.md)
for wiki work; update sources/canonical docs and let the scheduled workflow
regenerate pages unless direct wiki edits were explicitly requested.

## Checks and hooks

`hey check --worktree` is the shared local check. Commit/push invoke configured
hooks; use `prek` directly only for hook development/debugging or explicit
requests. Do not bypass hooks to manufacture success. No default pull/rebase,
push, deployment, or worklog is required for a local task.
