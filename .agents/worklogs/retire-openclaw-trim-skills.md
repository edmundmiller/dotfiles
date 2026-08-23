# Worklog: retire-openclaw-trim-skills

Status: complete

## Objective

Reduce shared skill-routing conflicts and retire OpenClaw-owned configuration. Stop when the cleanup is committed before skill-source updates, update-only changes are committed separately, focused checks pass, live runtime state matches the source, and unrelated dirty files remain unchanged.

## Decisions

- Prefer Codex and OMP native capabilities over overlapping shared skills.
- Preserve deterministic validators and genuinely distinct workflows.
- Treat OpenClaw runtime configuration as retired; do not remove unrelated upstream projects merely because their GitHub organization is named `openclaw`.
- Authority is local-only: commit, but do not push.

## Evidence

- Baseline: detached Git worktree at `d78d1c8dc6be26c4d02524aea315a9ec2f2b3b63`.
- Unrelated dirt to preserve: `modules/services/hass/default.nix` and `packages/herdr-plugins/default.nix`.
- Host: `MacTraitor-Pro.local`, Darwin arm64.
- Cleanup validation: `skill-quality` checked 54 skills with zero findings; `tests.test_agent_quality` ran 27 passing tests; Nix, YAML, and Nu parsing passed.
- Source update: `hey skills-update` refreshed both lockfiles, removed the retired Matt Pocock source, and `hey skills-sync` activated the shared, Codex, Pi, and OMP targets.
- Live Mac readback: 64 shared skills; removed overlaps are absent; `extending-pi` exists only in Pi; OMP has the expected eight ignored skills.
- Current-main validation: the scoped branch includes `origin/main` through `ea6593138`; `hey check` and the NUC configuration build exercise the integrated tree.
- Live NUC readback: `/run/current-system` is `/nix/store/pfw7d68ib3vm2sazf2anfqc1hrh0azxq-nixos-system-nuc-26.11.20260714.18b9261`; Home Assistant is active; the system closure has zero OpenClaw or Clawdbot references; no matching units or processes remain; `/run/agenix/clawdbot-bridge-token` is absent.
- Retired state: `/home/emiller/.openclaw` is absent; its recoverable archive is `/home/emiller/.local/state/retired/openclaw-20260822` with mode `0700`. The Mac copy was moved to Trash.
- Scope preservation: the assigned worktree still contains only the user's pre-existing Bluetooth adapter and Herdr plugin permission hunks outside the committed task changes.

## Reviews

Plan gate not required; no external reviewer requested.

## Feedback

The prior audit was read-only; cleanup recommendations must not be described as already applied.

- `hey skills-update` initially hit GitHub's anonymous API limit; a single authenticated retry via the existing `gh` session succeeded without persisting a token.
- `hey skills-sync` still warns about an obsolete `dotfiles-repo` input name.
- The NUC deployment guard correctly rejected the first stale-base snapshot after concurrent `main` changes; replaying the task on current `origin/main` resolved it.
- NUC activation preserved existing Hermes values when 1Password rate-limited reads. `opnix-secrets.service` remained failed for that unrelated provider error; the requested generation and Home Assistant service are live.
- Home Assistant has unrelated missing-package and stale-entity startup errors; none reference OpenClaw.

## Remaining work

None within this task. The 1Password/OpNix recovery and unrelated Home Assistant dependency errors are parked for separately scoped repairs.

## Commits

- `5f89fe3c5` — remove redundant shared workflows and narrow runtime routing.
- `544e52f93` — retire OpenClaw-owned configuration and integrations.
- `95e518385` — refresh skill-source pins after the cleanup commit.
- `76342c6bf` — integrate the concurrent current-main changes required by the NUC deployment guard.
- `db5535802` — remove the final unused Clawdbot bridge secret and encrypted artifact.
