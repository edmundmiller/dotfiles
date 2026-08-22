# Worklog: workspace-2qf.2

Status: active

## Objective

Deploy a reversible Scintillate-only Hermes v0.20.5 native Buzz UX pilot without changing sibling profile transports or packages. Stop after authoritative live DM, presence, version, and service-health proof.

## Decisions

- Use an isolated worktree from current `origin/main`; preserve the dirty canonical checkout byte-for-byte.
- Keep host-specific package selection and service wiring in dotfiles.
- Consume the canonical Buzz adapter patch from the agents-workspace input.
- Keep the existing Scintillate presence companion during the pilot.

## Evidence

- Host identity recorded before changes with `hostname` and `uname -a`.
- Upstream Hermes v0.20.5 `messaging` package built successfully on the NUC before implementation.
- Final pre-deploy `hey nuc-wt build` built `/nix/store/ilqr74lqc6x1jwi06zdmk84yvqlbal5k-nixos-system-nuc-26.11.20260714.18b9261`.
- The maintained `llm-agents` overlay built `hermes-agent-buzz-pilot-2026.8.19-runtime`; its install check reported Hermes Agent v0.20.5 and `Ran 7 tests ... OK`.
- Focused NUC builds passed for `nuc-hermes-buzz-pilot` and `nuc-buzz-hermes-community-runtime`.
- The rendered module keeps the fleet package unchanged and assigns the pilot package only to Scintillate's gateway profile and cron executor.

## Reviews

- Two-axis pre-deploy review found one hard packaging-ownership violation plus partial live proof, group reply scope, and overlapping reaction cleanup gaps.
- The implementation now uses the required `overlays/hermes-agent/` seam; flat replies are DM-only; working reactions are per turn and cleaned on disconnect; live proof remains intentionally open until deployment.
- Follow-up review's failed-cleanup gap is closed: failed reaction removals remain tracked for retry, with a seventh regression test. The optional RTK duplication finding was also removed.

## Feedback

None yet.

## Remaining work

- Deploy and verify live behavior.
- Commit, push, and prove remote equality.

## Commits

None yet.
