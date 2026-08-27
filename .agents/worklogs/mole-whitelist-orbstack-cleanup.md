# Worklog: mole-whitelist-orbstack-cleanup

Status: blocked

## Objective

Remove obsolete Docker Desktop data from MacTraitor-Pro without touching the
active OrbStack runtime, then improve and validate the Nix-managed Mole
whitelist for this laptop. Stop when runtime ownership and cleanup are read
back from live state, the deployed whitelist matches the requested protections,
and focused repository checks exercise the changed file.

## Decisions

- Treat Docker Desktop runtime data as removable under the user's explicit
  annotation, but preserve shared Docker CLI configuration and portable
  Docker/OCI/Compose artifacts used by OrbStack.
- Derive whitelist additions from current laptop state and Mole's installed
  matching semantics. Protect durable or expensive-to-recreate state, not every
  regenerable cache.
- The run began with local-only authority. The user's later explicit `$done`
  authorizes task-only commit, publication, proof, and workspace cleanup; it
  does not expand scope to an unrelated h5py package fix.
- Narrow Docker CLI protection to `config.json`, `daemon.json`, contexts, and
  buildx state. Remove only the retired `desktop-linux` context, Docker
  Desktop-only state, and broken links into the absent Docker.app; leave the
  OrbStack plugin directory unwhitelisted so future stale links remain visible.
- Do not prune active OrbStack images, volumes, or build cache; those are live
  daemon data, not Docker Desktop residue.

## Evidence

- `hostname` and `uname -a`: MacTraitor-Pro.local, Darwin arm64.
- `~/.config/mole/whitelist` currently resolves to a Nix store path sourced by
  `config/mole/whitelist` through `modules/shell/zsh/default.nix`.
- Schema-v2 run receipt:
  `/Users/emiller/.local/state/dotfiles-agent-runs/60f06f26572d/20260826T225825Z-209c8d5ee3d4.json`.
- Prior migration evidence says Docker.app was absent, OrbStack owned the
  `orbstack` Docker context, and Docker Desktop data was deliberately preserved;
  all runtime and filesystem facts will be re-read before removal.
- The custom whitelist now mirrors Mole's missing tealdeer default and protects
  OrbStack's group container, mount, runtime configuration, narrowly scoped
  Docker-compatible CLI state (including the builder GC policy in
  `daemon.json`), and downloaded Codex runtimes.
- The installed Mole matcher protects each added path and does not protect the
  retired Docker Desktop container, `.docker/bin`, or `.docker/models`.
- `git diff --check` and `hey check --worktree config/mole/whitelist` passed;
  the latter completed the Darwin, formatting, pre-commit, package, policy, and
  structural checks.
- Immediately before cleanup, `orbctl status` reported `Running`, Docker context
  was `orbstack`, and Docker server readback was OrbStack 29.4.0 with 6
  containers and 32 images. Docker.app and its privileged helpers were absent;
  OrbStack's privileged helper files were present. `lsof +D` found no open files
  under the retired Docker Desktop container.
- Exact retired Docker Desktop paths used 4,374,236 KiB. The `desktop-linux`
  context and all 26 exact residue paths were removed permanently; post-cleanup
  readback found zero remaining targets. Root free space increased from 94 GiB
  to 98 GiB.
- Post-cleanup readback preserved OrbStack's group container, mount, runtime
  config, Docker config/contexts/buildx state, and OrbStack buildx/compose
  plugins. OrbStack remained `Running`; Docker still reported the `orbstack`
  context, OrbStack 29.4.0, 6 containers, and 32 images.
- Release review found 528 KiB of hidden `desktop-linux` buildx refs plus its
  activity marker inside the protected buildx directory. Both exact paths were
  permanently removed; `docker buildx ls` still reports the OrbStack builder
  running and no `desktop-linux` builder.
- `docker system df` reports 24.19 GB of reclaimable images and 2.427 GB of
  unlinked volumes in the active OrbStack daemon. These were deliberately left
  intact because they are not retired Docker Desktop data.
- Two `hey re` activation attempts failed at the same unrelated h5py 3.15.1
  `test_register_filter` abort (`Abort trap: 6`) after earlier Nix garbage
  collection. No whitelist-specific supported activation route exists. Live
  `~/.config/mole/whitelist` still points at the prior Home Manager generation
  and `cmp` confirms that the source update is not activated.
- `hey agent-audit-tests config/mole/whitelist` passed `test-confidence`, and
  `hey agent-finish --worklog ...` passed all Darwin checks plus 56 agent-quality
  tests. These gates were rerun after the final whitelist additions.

## Reviews

- Plan gate attempted with
  `hey agent-review plan --active-model-family openai --worklog .agents/worklogs/mole-whitelist-orbstack-cleanup.md`.
  The reviewer stopped at ACP `session/new` with
  `RUNTIME: Authentication required`; no findings were produced. The user's
  explicit, bounded cleanup and whitelist request remains the operative plan.
- Parallel read-only audits confirmed the active OrbStack path boundaries,
  found the missing built-in tealdeer protection and Codex runtime risk, and
  identified 4.17 GiB of removable Docker Desktop residue. Safety review asked
  that the original broad `~/.docker` protection be narrowed; the source now
  protects only OrbStack-compatible durable CLI state.
- A focused activation-route review found that Mole's file is deployed through
  the complete Home Manager generation and `hey re` always performs the full
  Darwin rebuild. Manual symlink replacement would violate the repository's
  Nix-managed activation boundary and will not be used.

## Feedback

- Mole 1.37 intentionally skips Docker Desktop containers, so the obsolete VM
  could not be reclaimed through Mole itself. Its Trash count also omitted
  Docker.app even though that item used 2.40 GiB; cleanup therefore used only
  explicit, pre-measured Docker Desktop paths and did not empty unrelated Trash.
- Earlier Nix garbage collection made this small Home Manager change rebuild a
  large user profile. The resulting h5py test abort is unrelated to the Mole
  whitelist and should not be hidden by bypassing the supported activation path.
- The failed rebuilds created reproducible dead Nix store paths. A dry run found
  17,242 paths, but the repository-supported `hey gc` requires an interactive
  sudo password (`sudo -n true` failed). During `$done`, root free space fell
  below 16 GiB (14 GiB at the final pre-commit readback); the supported GC was
  opened for user authentication but could not be completed without that
  credential.

## Remaining work

- Activation requires either a separately scoped fix for the unrelated h5py
  package build or a later successful full `hey re`; direct symlink replacement
  would bypass the repository's Home Manager policy.
- Repository closeout is authorized by the explicit `$done`; terminal revision
  and remote-equality proof are recorded in the run receipt.

## Commits

- The task change and this evidence log are shaped together during `$done`;
  immutable revision identifiers are recorded by the terminal run receipt.
