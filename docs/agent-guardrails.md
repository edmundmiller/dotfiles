---
purpose: Define repository-wide safety, documentation, tooling, and landing rules for agents.
applies_to: Every change in this nix-darwin dotfiles repository.
entrypoint: Read root AGENTS.md, then apply the relevant guards below.
verification: Inspect the changed artifact and run the routed focused check.
update_when: Shared editing, deployment, documentation, or landing rules change.
---

# Agent guardrails

## System safety

- Before host-specific action, run `hostname` and `uname -a`; never infer the
  host.
- Treat managed runtime files as read-only Nix store symlinks. Edit repository
  sources, not generated or deployed targets.
- For state-changing Nix, Darwin, NUC, skills-catalog, cleanup, or Homebrew
  work, use the repository's `hey` interface. Use `hey re` or `hey rebuild`
  for Darwin activation, and `hey skills-update` or `hey skills-sync` for
  skills-catalog changes. [ADR 0001](adr/0001-agent-command-policy.md) is
  authoritative; do not bypass it with lower-level commands.
- Do not evaluate `nixosConfigurations.nuc` on Darwin. Use `hey nuc-wt build`,
  `hey nuc dry-activate`, or `hey nuc`.
- Never expose decrypted agenix or opnix secrets; pass secret paths or
  environment references instead.
- Never edit generated files directly; follow their header to the source
  manifest or generator.

## Documentation

Canonical docs change with the behavior, ownership, commands, or recovery
steps they describe. Start each new or changed canonical document with this
summary, closed by line 7:

```yaml
---
purpose: Why this doc exists.
applies_to: When an agent should read it.
entrypoint: First file, command, or action.
verification: How to prove the documented system works.
update_when: What changes require this doc to change.
---
```

Name the source of truth and a live check for facts that can drift. Generate
inventories rather than copying them. Put ownership and recovery instructions
in the subsystem's canonical doc. When docs and reality disagree, verify
reality, fix the doc and its enforcement, and record repeated friction in
worklog `Feedback`. Use ordinary words, short sentences, and one idea per
section. Search summaries instead of reading every doc; do not maintain a
static file inventory.

OpenWiki is generated documentation: begin with [openwiki/quickstart.md](../openwiki/quickstart.md)
and do not hand-edit generated OpenWiki pages unless explicitly requested. Its
scheduled GitHub Actions workflow refreshes the repository wiki, so prefer
updating source code or canonical docs and letting OpenWiki regenerate.

## Tooling and landing

Load matching skills before acting. Use `fff` to find files when it is
available, `sem diff` for review, and `git hunks` for selective staging.

Every repository session ends with focused checks, commit, pull or rebase,
push, and upstream verification when those actions are authorized. Qualifying
work follows [AGENT_WORKFLOW.md](../AGENT_WORKFLOW.md).
