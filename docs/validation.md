---
purpose: Define one predictable validation workflow for local work and CI.
applies_to: Dotfiles source edits, package QA, and explicit platform validation.
entrypoint: hey check
verification: python3 -m unittest tests/test_validation.py
update_when: Validation routing, check ownership, or CI jobs change.
---

# Start with `hey check`

| Command                            | Scope                                                                              |
| ---------------------------------- | ---------------------------------------------------------------------------------- |
| `hey check`                        | Changed files, affected repository tests, Pi/OMP packages and dependents           |
| `hey check path...`                | The same routing, limited to changed task-owned paths                              |
| `hey check --plan`                 | JSON selection only; no check execution or source snapshot                         |
| `hey check --full`                 | All portable checks, formatting/lint, all workspace packages and integration tests |
| `hey check --platform darwin`      | Both host derivations and native checks, aarch64 Darwin only                       |
| `hey check --platform nixos`       | Full Linux flake check, including host, deployment and VM checks                   |
| `hey check --platform herdr-vm`    | Herdr integration VM only, x86_64 Linux                                            |
| `hey check --platform services-vm` | Service VM suite only, x86_64 Linux                                                |

Use the repository dev shell (`nix develop`) or installed dotfiles tools. The
runner needs Python 3.11+, Git, Nix and Prek; package QA needs Bun/Node.
CI invokes `python3 scripts/validation.py`, the exact implementation
behind `hey check`, without starting the host-oriented `hey` environment.

Selection includes committed branch changes relative to the merge-base with
`origin/main`, plus staged, unstaged and untracked files. Without `origin/main`,
it uses `HEAD` and checks working changes. `--base-ref REF` makes the baseline
explicit; invalid refs fail. Fetching is never implicit. Paths are relative to
the repository root. Renames select both owners; deleted paths still route tests.
`--full` cannot be combined with path scopes. `--worktree` remains an accepted
compatibility flag but is redundant.

## Checks never repair the working tree

Checks copy tracked and non-ignored untracked source into a temporary Git
repository, with current working bytes rather than staged bytes. Formatters,
package installs and tests run there. The source index, dependency symlinks and
dirty files stay untouched; the snapshot is removed on exit. External symlinks
and submodules fail explicitly rather than escaping that boundary. Tool caches
and Nix store downloads are allowed; this is source isolation, not a security
sandbox for malicious tests. Source changes during the run invalidate its result.

The runner streams native diagnostics, names failed suites, continues independent
suites and exits nonzero if any fail. A formatter that changes snapshot source
also fails. Run `nix fmt` to intentionally fix formatting, review its changes,
then rerun `hey check`. Missing tools or private inputs are failures with concrete
diagnostics, never silent passes. Snapshot commits explicitly disable signing;
real commits retain the user's signing policy.

Read-only tasks have no automatic stop hook. Agents select owned paths, fix
task-caused failures, and report baseline or unavailable checks without being
forced into unrelated repairs. Evidence remains useful until its inputs change;
there is no one-shot completion token or persistent success cache.

## CI uses the same selection

`Checks (Linux)` runs the shared portable runner. PRs use
the PR base SHA; pushes use the previous SHA. `--ci` consumes `VALIDATION_BASE`;
manual/new-branch events with no usable base run the full portable suite. The
Herdr job keeps its existing name but reports success without a VM build when
its inputs are unchanged. Native Darwin checks now cover affected PRs too; service
VMs stay manual. Platform commands never activate or deploy a host.

Darwin evaluates each host's `system.drvPath`, not merely its outer attribute set.
Herdr's import-from-derivation requires a native Darwin builder even during
evaluation, so Linux cannot certify this check. The CI job uses ARM64 `macos-15`.
`Checks (Linux)` also requires that native job to succeed, preserving the existing
required status. Native checks do not repeat the portable formatting/lint suite.

`scripts/validation.py` owns suite routing. `flake.nix` owns the immutable
`pre-commit-config` and Nix derivations. The full portable route omits host and
VM evaluations deliberately: release verification is `hey check --full` plus
the platform command for the target, on a suitably sized builder with private
input access. GitHub's repository-scoped token cannot fetch every private input.
The Linux-only TRMNL browser renderer belongs to `--platform nixos`; its source
structure check remains in changed-work and portable validation on both systems.

## Validate a candidate on the NUC

From any checkout that can SSH to the NUC, run `hey nuc-wt validate`. The command
copies the exact clean commit or dirty worktree into a uniquely leased NUC
snapshot, then runs all release gates without activating or deploying anything:

```sh
python3 scripts/validation.py --full
python3 scripts/validation.py --platform nixos
nix flake check --keep-going -L
```

Every gate runs even if an earlier gate fails. Separate logs under the printed
`NUC_VALIDATION_REPORT_DIR` retain output; `summary.tsv` records every exit
status and log-write status. `state.tsv` ends in `completed` only when the gates
and snapshot cleanup succeed. Setup, gate, logging, submission, cleanup, and
interruption failures end in `failed` with the cause. `unit.txt` and
`provenance.txt` retain the transient unit identifier. The command waits for the
result and exits nonzero when the terminal state is failed. The service
finalizer writes that state and releases the snapshot lease, including after a
signal or OOM kill. A run continues if the calling Amp runner or SSH session
disconnects after submission. A global NUC lock serializes these memory-heavy
runs. Nix builds use one job and two cores. The service-owned snapshot lease
remains protected while that exact unit is queued or running, even after the
usual 24-hour lease timeout. Pruning removes the stale lease after the service
exits.

The transient user service limits its evaluator and client processes to a 10 GiB
soft limit and a 12 GiB hard limit. Before each gate, the runner reads
`MemAvailable` from `/proc/meminfo` and refuses to start the gate unless at least
16 GiB is available. A missing or malformed reading also fails closed. A
preflight failure has status 75 in `summary.tsv`, and the other gate preflights
still run.

This is not a builder memory limit. Nix submits builds to the system
`nix-daemon`; its workers and KVM guests run outside the transient user service's
cgroup. They remain uncapped and can consume the 16 GiB observed at gate start.
Other host workloads can also consume memory after the check. A hard builder
boundary would require a privileged system service or daemon configuration
change. `provenance.txt` records both the evaluator boundary and the missing
builder boundary for every run.

Use one Git worktree per thread. NUC snapshots and reports are unique. Dirty
transfers build an immutable Git tree from tracked files and non-ignored
untracked files, then reject the transfer if the source tree changes while the
archive is copied. This keeps tracked ignored source, including `.pi` content,
without copying ignored runtime state. The report provenance records the Git
tree content digest, so a `HEAD-dirty` revision identifies the exact bytes that
the NUC reconstructed and tested.

When invoked in an isolated checkout on the NUC itself, the command uses a local
snapshot and needs no SSH or Tailscale hop. From another machine, the existing
`ssh nuc` route works even when the Amp runner is down, as long as the NUC and
SSH route are online. Once submitted, reconnect and inspect the printed report
directory if the caller disconnects. A powered-off or unreachable NUC cannot
accept or execute queued Linux/KVM work.

Synced snapshots get isolated Git metadata for validation; source history,
checkout credentials, inherited Git hooks, and the caller's `.git` directory are
not copied. Native Darwin verification remains a separate
`hey check --platform darwin` run in an isolated worktree on MacTraitor-Pro. The
NUC cannot certify it. An unpushed or dirty candidate must be transferred to that
Mac worktree explicitly; runner availability alone does not transfer source.

Pi/OMP workspace manifests and lock/config changes select every package.
Package edits select that package and transitive workspace consumers, then run
their declared typecheck/test scripts and integration tests. Dependencies install
with the frozen lockfile inside the snapshot. `bin/qa-changed` is only a
compatibility shim for publication and older callers. `pkg-check <unit>` remains
separate: it clones upstream, applies carried patches and runs upstream tests.
`hey ztest` remains a focused interactive shell-test helper, not another CI suite.

## Hooks and migration

Commit hooks retain fast formatting/lint. Expensive OMP checks now belong to
the shared runner instead of forcing an OMP build just to create hook config.
Pre-push safety (identity, submodules, HA assertions, runtime drift), Beads sync,
and deployment guards remain separate from source validation. Commit/push hooks
can mutate supported state; `hey check` does not run those stages.

Claude Code plugins and their validators are removed. If the retired
`Validate Claude Code Plugins` status was required in GitHub settings, an
administrator must remove that requirement before merging; deleting source
does not change branch protections. Re-enter the dev shell to regenerate
installed Git hooks; restart existing Codex/OMP sessions to unload old stop hooks.
Generated OpenWiki pages and historical worklogs are not workflow authorities.
