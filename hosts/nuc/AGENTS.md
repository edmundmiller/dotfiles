# NUC

NixOS home server, user `emiller`, timezone America/Chicago. Access via `ssh nuc`.
`default.nix` owns service selection; [deployment runbook](../../docs/runbooks/deploy-nuc.md)
owns deployment/recovery. Do not evaluate `nixosConfigurations.nuc` on Darwin;
the agent-skills platform mismatch requires Linux/NUC evaluation.

## Deployment provenance

`hey nuc-wt build` builds an isolated snapshot of the current worktree on NUC;
`vm` builds its VM. Uncommitted snapshots allow only those two actions.
`hey nuc-wt` defaults to dry-activate; `test` and `switch` activate and require a
clean commit. Use the printed `NUC_WORKTREE_REMOTE_DIR` for checks on that exact
snapshot. Active leases protect builds; pruning retains five recent snapshots.

`hey nuc` is the deployment interface. Daily auto-upgrade resolves current main
to an exact commit through `nix-private-github`, failing before activation if
resolution fails. Its opnix token is root-only. There is no persistent
`~/dotfiles-deploy` clone to repair or recreate.

## Runtime ownership

- Hermes uses `pkgs.llm-agents."hermes-agent"` plus `overlays/hermes-agent/`,
  including the declarative Honcho SDK. Mutable pip repairs are not package fixes.
  Inspect `hermes-agent.service` and profile `hermes-gateway-*` units; timer
  executors and `$HERMES_HOME/cron/executor.json` stay synchronized.
- QMD uses llm-agents packaging. The host wrapper sets `NODE_LLAMA_CPP_GPU=off`;
  state stays under `~/.cache/qmd`, `~/.cache/node-llama-cpp`, and `~/.config/qmd`.
- Relaxed Nix sandbox permits network-dependent `__noChroot` builds. Generic
  Linux binaries use `programs.nix-ld`; missing libraries are diagnosed with `ldd`.
- Podman provides the Docker-compatible CLI/API. The manuscript Amp runner unit
  targets `~/src/fg/nascent-manuscript-main`; the official installer owns `~/.amp`.
- `~/.local/bin/tnote` targets `~/src/personal/tnote`, with no legacy fallback.
- Scintillate's declared vault `/home/hermes/repos/obsidian-vault` may resolve
  inside its compatibility container to `/home/emiller/obsidian-vault`; `.git`
  must exist at the resolved mount.

## Data and recovery constraints

- General and audiobook backups use separate R2/restic repositories. BorgBase
  is quota-limited to 10 GB; keep large media out. Preserve one `/audiobooks`
  backup unless retention/restore requirements justify splitting it.
- R2 uses restic's S3 backend directly. Agenix environment files carry
  `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `RESTIC_PASSWORD`, and
  `RESTIC_REPOSITORY`; no rclone is needed. ZFS/znapzend remains disabled.
- HA `.storage` persists across rebuilds; do not edit it directly. Declarative
  automation startup policy is defined in the HA domain guide. NUT owns USB UPS
  and shutdown; HA is a loopback read client. [UPS.md](UPS.md) covers recovery;
  routine checks must not invoke power-cut commands.
- Mill Docs pull conflicts are reported as Healthchecks failures even when the
  service exits successfully. Preserve its index/stash; do not reset, clean,
  abort, or drop data to make the timer green. Resolve the conflict, then verify
  the next authorized service run from its journal.
- Linear OAuth bootstrap seeds `~/.local/state/hermes-linear/token` only when
  absent. `bin/linear-oauth-refresh` recovers access/refresh tokens from a Mac;
  `--no-deploy` still reauthorizes, encrypts, and seeds state. The full command
  also deploys. It needs browser consent and SSH, with callback on port 9999.
- Gatus monitoring and dead-man's-switch details belong in
  [its module guide](../../modules/services/gatus/AGENTS.md).
