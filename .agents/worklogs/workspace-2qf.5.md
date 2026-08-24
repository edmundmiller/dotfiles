# Worklog: workspace-2qf.5

Status: active

## Objective

Unify the NUC Hermes fleet on v0.20.5, deploy five native Buzz-facing bots
with final-only presentation and real smart approvals, preserve the internal
Orchestrator boundary, and stop only after authoritative live and remote
landing proof.

## Decisions

- Use the canonical agents-workspace renderer for runtime behavior and this
  repository only for host package, secret, service, and deployment wiring.
- Keep exactly one message-processing transport per Buzz identity; retain a
  separate presence-only publisher until native Buzz supports presence.
- Roll out from clean task worktrees and migrate one profile at a time.

## Evidence

- Agents-workspace start revision: `7d578928772ad5ffc81266930a7ce7b6720606ce`.
- Agents-workspace landed revision: `6cd817e004fe67839b788d2b97d15a9806406988`.
- Dotfiles start revision: `baf5a44155b16ee6e0144a0ddbda2fc920596876`.
- Receipts:
  - `/Users/emiller/.local/state/dotfiles-agent-runs/d15c9afe3310/20260824T033804Z-f4649128e143.json`
  - `/Users/emiller/.local/state/dotfiles-agent-runs/908b31f00425/20260824T033921Z-5e73fce5ea11.json`
- Agents-workspace full flake check passed; the focused native Buzz suite passed
  11 tests. Remote `origin/main` was read back at the landed revision.
- `hey nuc-wt build` built the all-native NUC generation at
  `/nix/store/yffxxm6jirqlpxkh1lcc9prfni981vj1-nixos-system-nuc-26.11.20260714.18b9261`.
- NUC builds passed for the all-native fleet assertions, Scintillate-only
  staged assertions, shared v0.20.5 package, external cron executor, and cron
  failure summary.
- Pre-switch live baseline is generation
  `/nix/store/4xzl157286dlcdmqy8z50xfm43a10xgb-nixos-system-nuc-26.11.20260714.18b9261`:
  Scintillate native plus presence are active at v0.20.5; Finn, Amos Burton,
  Anne, and Betty ACP lanes are active; their native gateways are masked; all
  reported `NRestarts=0`. Orchestrator remains v0.19.1.
- The NUC has no deployment lock or active rebuild process. Its pre-existing
  degraded state is from failed Mill Docs pull/coding-agent and Obsidian vault
  dirt-check units, not a Hermes unit.
- Local parse and `git diff --check` passed for every changed Nix source.
- The repository-wide local flake evaluation still reaches the pre-existing
  aarch64-darwin `chip-ota-provider-app` x86-only failure. The unrelated
  `nuc-hermes-cron-executors` check still expects a retired Radar unit; neither
  failure is in this task's changed behavior.

## Reviews

- Pre-implementation release-plan review found five required corrections:
  enforce policy after overlays, define control-message exceptions, prove all
  package lanes, preserve Bot metadata ownership, and make cutover XOR/rollback
  acceptance executable. The implementation incorporates all five.
- Deployment review found no switch-order blocker and required container-level
  Hermes version readback because the host package is a different profile.
- Release review required permission-denying staged ACP fallback, a live staged
  evaluator, and explicit Discord typing. All three are implemented and the
  corresponding NUC checks pass; re-review is pending.

## Feedback

- The routed `dotfiles-agent-workflow` skill was not installed; this run uses
  the repository-owned `AGENT_WORKFLOW.md` fallback.

## Remaining work

- Complete release re-review, commit the dotfiles implementation, perform the
  ordered NUC cutover, run user-visible Buzz acceptance, land remotely, and
  close the issue with authoritative readback.

## Commits

- Agents workspace: `6cd817e004fe67839b788d2b97d15a9806406988`.
