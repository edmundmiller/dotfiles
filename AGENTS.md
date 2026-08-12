---
purpose: Route agents to the smallest authoritative workflow, skill, doc, or tool.
applies_to: Every task in this nix-darwin dotfiles repository.
entrypoint: Inspect the checkout, then follow the matching route below.
verification: Run the routed check; use `hey check` for Darwin changes.
update_when: A route, ownership boundary, or repository-wide guard changes.
---

# Agent router

This is a Nix-managed macOS and NixOS dotfiles repository. Package management,
builds, and deployments use Nix through `hey`: use `hey re` or `hey rebuild`
for Darwin activation, and `hey skills-update` or `hey skills-sync` for skills
catalog changes.

1. Confirm the assigned checkout and preserve unrelated changes.
2. Read the nearest nested `AGENTS.md` before changing a subsystem.
3. Read [agent guardrails](docs/agent-guardrails.md) for repository-wide
   safety, documentation, tooling, and landing requirements.

## Route by task

- Broad, autonomous, high-risk, or multi-session work: load
  `dotfiles-agent-workflow`, then follow [AGENT_WORKFLOW.md](AGENT_WORKFLOW.md).
- Documentation: search the first seven lines under `docs/` for `purpose:`,
  `applies_to:`, or `update_when:`, then read the match.
- Agent rules, modes, or runtime configuration:
  [config/agents/AGENTS.md](config/agents/AGENTS.md).
- Skills: [skills/AGENTS.md](skills/AGENTS.md), then load the matching skill.
- Package or overlay: its nested `AGENTS.md`; use `pkg-list` and
  `pkg-check <unit>`.
- Darwin or Nix work: load `nix-darwin-reference`; use `hey` when it provides
  the operation.
- NUC deployment: [deploy-nuc.md](docs/runbooks/deploy-nuc.md).
- Agent quality gates: [agent-quality.md](docs/agent-quality.md).
- OpenClaw or Hermes runtime behavior: work in `agents-workspace`; this repo
  owns only host deployment wiring.
