# Worklog: herdr-hunk-skills

Status: completed

## Objective

Replace thin upstream-only Herdr and Hunk guidance with checkout-owned skill packages that encode current official CLI behavior, trace-derived recovery patterns, reusable references, and deterministic helpers. Stop when both installed skills expose all bundled resources, focused checks and runtime smoke tests pass, the host is rebuilt, and the branch is pushed/current upstream.

## Decisions

- Treat current installed versions as executable truth; use upstream docs for intent, then verify commands locally.
- Keep trace mining targeted and retain workflow patterns only.
- Prefer Herdr `agent` commands over pane-level lifecycle orchestration; keep pane primitives as fallback.
- Preserve Hunk live-session control as primary; add this repo's resumable worktree review workflow and OMP internal-resource path.

## Evidence

- Host: `MacTraitor-Pro.local`, Darwin arm64.
- Installed Hunk: `0.17.0`; `hunk session --help`, `hunk resume --help`, and `hunk skill path` inspected.
- Installed Herdr: protocol 16; `herdr agent --help` and `herdr api schema` inspected.
- Official Herdr socket API and Hunk agent workflow docs inspected.
- Targeted Pi JSONL searches exposed stale-ID guessing, brittle pane startup prompts, unsupported flags, config reload gaps, over-broad Hunk setup, and successful structured session/comment workflows.
- Four Python helpers compiled from source without bytecode writes.
- Hunk batch helper accepted a valid payload, rejected an invalid multi-target payload, and emitted the deployed `hunk session comment apply --repo … --stdin` command shape under a fake binary.
- Herdr context helper emitted bounded agent metadata, transcript, and explain JSON under a fake binary.
- `hey check` passed Darwin evaluation, lock sync, tmux tests, and package harness tests.
- `darwin-rebuild switch --flake .` succeeded after staging new flake source paths.
- Installed `~/.agents/skills/herdr`, `~/.agents/skills/hunk-review`, and Pi-targeted `herdr-pi-workspace` all contain their referenced nested resources; installed Hunk helper smoke passed.
- Removed obsolete child-flake `hunk-repo` and `herdr-repo` inputs; refreshed both child and root locks with `nix flake update skills-catalog`.
- Final `darwin-rebuild switch --flake .`, `hey agent-finish`, and `hey check` passed.

## Reviews

- Plan gate attempted with default Claude and Gemini reviewers; both failed at ACP session creation with `Authentication required`. No heterogeneous reviewer is currently authenticated, so the gate is recorded as tooling-blocked.
- Both requested `skill-reviewer` package reviews failed before execution because the subagent runtime has no selected model. Recorded as tooling-blocked; manual resource/link and command-shape checks completed.
- Landing review via Gemini also failed at ACP session creation with `Authentication required`; manual semantic diff review found no out-of-scope changes.

## Feedback

- Upstream Herdr skill lags current agent/worktree/layout/plugin CLI capabilities and old ID examples encourage hard-coding.
- Pi receives a separate `herdr-pi-workspace` target skill. It overlaps the global Herdr skill; its launch helper has a duplicate shebang and brittle Pi-specific readiness text, so keep its focused handoff contract but modernize it around Herdr agent commands.
- Upstream Hunk skill omits this repo's `hunk resume` paired worktree workflow and OMP `hunk://` resources.

## Remaining work

None.

## Commits

- `feat(skills): deepen Herdr and Hunk workflows` (this commit)
