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
- The final generation is `/nix/store/c6yq83pqw5dy3n150m445lmksf3gpllh-nixos-system-nuc-26.11.20260714.18b9261`; its Scintillate container was recreated because the package PATH changed.
- Live readback reports Hermes Agent v0.20.5 from both bare and explicit package commands, Buzz connected as Scintillate, presence online, and a successful cron tick.
- The final deployment left Amos Burton, Anne, Betty, Finn, and Orchestrator active on the same PIDs with `NRestarts=0`.
- Activation also surfaced an unrelated existing `mill-docs-git-pull.service` failure caused by unmerged files; the mill-docs checkout was not touched.

## Reviews

- Two-axis pre-deploy review found one hard packaging-ownership violation plus partial live proof, group reply scope, and overlapping reaction cleanup gaps.
- The implementation now uses the required `overlays/hermes-agent/` seam; flat replies are DM-only; working reactions are per turn and cleaned on disconnect; live proof remains intentionally open until deployment.
- Follow-up review's failed-cleanup gap is closed: failed reaction removals remain tracked for retry, with a seventh regression test. The optional RTK duplication finding was also removed.

## Feedback

None yet.

## Remaining work

- Observe one post-deploy natural DM in Buzz to confirm the working reaction and flat visible reply in the real client; automated adapter coverage is green, but no post-deploy user turn has arrived yet.

## Commits

- `7491443` — Scintillate-only v0.20.5 pilot package and deployment wiring.
- `d827921` — expected-failure regression for the v0.20.5 cron patch syntax.
- `a6012c7` — context-anchored cron patch and latest-source behavior checks.
- `6439c18` — package-aware container recreation pin.
