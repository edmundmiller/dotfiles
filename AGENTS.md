---
purpose: Route agents to the smallest authoritative workflow, skill, doc, or tool.
applies_to: Every task in this nix-darwin dotfiles repository.
entrypoint: Match the task in the routing table before reading deeper context.
verification: Use the routed subsystem check, then `hey check` for Darwin changes.
update_when: A route, ownership boundary, command, or recurring failure changes.
---

# Agent router

This repo manages read-only Nix store symlinks. Edit their source here, then rebuild.

## Route first

Read only the rows that match the task. The nearest nested `AGENTS.md` adds local rules.

| Task                                                  | Read or use                                                                                                            |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Broad, autonomous, high-risk, or multi-session change | Load `dotfiles-agent-workflow`, then follow `AGENT_WORKFLOW.md`                                                        |
| Find system documentation                             | Search `purpose:`, `applies_to:`, or `update_when:` in the first seven lines under `docs/`, then read the match        |
| Change a subsystem                                    | Its nearest nested `AGENTS.md`; use `fff` to find it                                                                   |
| Change agent rules, modes, or runtime config          | `config/agents/AGENTS.md`                                                                                              |
| Add or update skills                                  | `skills/AGENTS.md`; load `skill-development` or `skill-quality`                                                        |
| Maintain a package or overlay                         | Its nearest nested `AGENTS.md`; use `pkg-list` and `pkg-check <unit>` for package validation, `hey` for host lifecycle |
| Darwin or Nix work                                    | Load `nix-darwin-reference`; use `hey`, not raw Nix when a wrapper exists                                              |
| NUC deployment                                        | `docs/runbooks/deploy-nuc.md`; validate on the NUC                                                                     |
| Agent quality gates                                   | `docs/agent-quality.md`; use `hey agent-*` commands                                                                    |
| OpenClaw/Hermes runtime behavior                      | Work in `agents-workspace`; this repo owns host deployment wiring only                                                 |

For skills, load any matching `skill://<name>` before acting. For files, use `fff` search tools. Prefer `sem diff`; use `git hunks` for selective staging.

## Non-negotiable guards

- Before host-specific action, run `hostname` and `uname -a`. Never infer the host.
- On Darwin, never evaluate `nixosConfigurations.nuc` locally. Use `hey nuc-wt build`, `hey nuc dry-activate`, or `hey nuc`.
- After changing Nix-managed config, run `sudo /run/current-system/sw/bin/darwin-rebuild switch --flake .`.
- After changing `skills/flake.nix` or `skills/flake.lock`, run `nix flake update skills-catalog` at repo root.
- Never expose decrypted agenix/opnix secrets. Pass secret paths or environment references, not values.
- Never edit generated files directly. Follow their header to the source manifest or generator.
- Every repository session MUST finish with focused checks, commit, pull/rebase, push, and verification that the branch is current upstream. Follow `AGENT_WORKFLOW.md` for qualifying work.

## Documentation contract

Canonical docs are part of the system they describe. Update them in the same change when behavior, ownership, commands, or recovery steps change.

Every new or touched canonical doc starts with a short YAML summary whose closing `---` appears by line 7. Use:

```yaml
---
purpose: Why this doc exists.
applies_to: When an agent should read it.
entrypoint: First file, command, or action.
verification: How to prove the documented system works.
update_when: What changes require this doc to change.
---
```

Keep docs self-healing:

- Name the source of truth and a live command for facts that can drift.
- Generate inventories instead of copying them.
- Put ownership and recovery instructions in the subsystem's canonical doc.
- When docs and reality disagree, verify reality, fix the doc and its enforcement, and record repeated friction in worklog `Feedback`.
- Use ordinary words, short sentences, and one idea per section.

Search summaries instead of reading every doc. Do not maintain a static file inventory here.
