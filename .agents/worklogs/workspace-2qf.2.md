# Worklog: workspace-2qf.2

Status: pilot running

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
- The first switch activated the new generation but left Scintillate's guarded gateway on its prior process; the cron tick exposed an `IndentationError` because the external-executor patch used a zero-context line-number hunk against v0.20.5.
- The cron patch is now anchored to `cron_status()` context and applies with zero fuzz to both the fleet source and v0.20.5. The rebuilt pilot install check passes the 7 Buzz cases, 1 cron compile regression, and 5 external-executor cases.
- The repaired NUC build produced `/nix/store/c9hl16vaviygihlqkmqm3k7z8gjnsp7s-nixos-system-nuc-26.11.20260714.18b9261`.
- The final reviewed build produced `/nix/store/zk4xk4bbjc33lnj8ms40bkvmyrzmk5zd-nixos-system-nuc-26.11.20260714.18b9261`; the focused `nuc-buzz-hermes-community-runtime` check passed on the NUC.
- The host timer now atomically writes a `0600` executor heartbeat after each successful tick. The gateway container reads the shared marker and `hermes cron status` reports the external timer running without container access to host systemd.
- The guarded gateway required one explicit restart to adopt the reviewed package. Live readback reports Hermes Agent v0.20.5, Buzz connected as Scintillate with five gateway platforms running, presence online, and a fresh successful cron heartbeat.
- The final deployment left Amos Burton, Anne, Betty, Finn, and Orchestrator active with `NRestarts=0`; their PID changes were the expected serialized activation restart.
- Activation also surfaced an unrelated existing `mill-docs-git-pull.service` failure caused by unmerged files; the mill-docs checkout was not touched.

## Reviews

- Two-axis pre-deploy review found one hard packaging-ownership violation plus partial live proof, group reply scope, and overlapping reaction cleanup gaps.
- The implementation now uses the required `overlays/hermes-agent/` seam; flat replies are DM-only; working reactions are per turn and cleaned on disconnect; live proof remains intentionally open until deployment.
- Follow-up review's failed-cleanup gap is closed: failed reaction removals remain tracked for retry, with a seventh regression test. The optional RTK duplication finding was also removed.
- Final standards review found that container-side cron status could not query the host timer. A red/green regression pair now uses the existing CLI and evaluated-service seams: six external-executor tests pass, and the deployed shared heartbeat is authoritative and fresh.

## Feedback

None yet.

## Remaining work

- Observe one post-deploy natural DM in Buzz to confirm the working reaction and flat visible reply in the real client; automated adapter coverage is green, but no post-deploy user turn has arrived yet.

## Commits

- `7491443` — Scintillate-only v0.20.5 pilot package and deployment wiring.
- `d827921` — expected-failure regression for the v0.20.5 cron patch syntax.
- `a6012c7` — context-anchored cron patch and latest-source behavior checks.
- `6439c18` — package-aware container recreation pin.
- `5ccc23e` — expected-failure regressions for container-visible cron health.
- `4f252be` — host heartbeat reporting, materialization, and evaluated service coverage.
