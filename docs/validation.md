---
purpose: Define one predictable validation workflow for local work and CI.
applies_to: Dotfiles source edits, package QA, and explicit platform validation.
entrypoint: hey check
verification: python3 -m unittest tests/test_validation.py
update_when: Validation routing, check ownership, or CI jobs change.
---

# Start with `hey check`

`mise run check` is the primary task; `hey check` is its compatibility spelling.
Both run `bin/hey.d/check`, which delegates to the same Python runner as CI.
Run them inside the checkout, or use `mise --cd <checkout> run check`.

| Command                            | Scope                                                                              |
| ---------------------------------- | ---------------------------------------------------------------------------------- |
| `hey check`                        | Changed files, affected repository tests, Pi packages and dependents               |
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

On x86_64 Linux, HA and NUC changes also select `ha-automation-assertions`,
`ha-behavior-tests`, and `ha-robot-cleaning-tests`. The behavior checks run the
exported Good Morning, bedtime-audio, entrance-light, pet NFC, Monica bedtime,
and robot-cleaning routines in isolated Home Assistant instances inside the Nix
sandbox, without physical integrations or live credentials. Normal Linux CI runs
these checks through the same selection. Other architectures omit these
Linux-only checks; a successful macOS check does not verify HA behavior.

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
the PR base SHA; main pushes use the previous SHA. Candidate pushes use the
explicit base encoded in `candidate/BASE/SHA`, not the all-zero before-SHA
of a new branch. The planner rejects mismatched candidate refs, non-ancestor
bases, or main that has moved beyond that base. `--ci` consumes `VALIDATION_BASE`;
manual events with no usable base run the full portable suite. The
lightweight platform planner runs the same selector without Nix before allocating
the Herdr VM runner and passes the same base to Linux and Herdr. Unaffected
Herdr work is explicitly skipped. Planning can run on either platform without
a native builder. See [candidate admission](runbooks/candidate-ci.md) for the
pre-main publication route and the separately approved live settings.

Ordinary PR, candidate and main-push CI allocates no Mac runner. Linux waits only
for lightweight planning, not Darwin;
green default CI certifies portable/Linux checks, not Darwin. Before Mac activation,
run `hey check --platform darwin` on the exact candidate, or explicitly dispatch
CI on that candidate with `darwin=true`. The optional job always runs native
validation, even when the candidate has no changed files. Service VMs are separately
opt-in with `services_vm=true`. Neither platform command activates or deploys a host.

Darwin evaluates each host's `system.drvPath`, not merely its outer attribute set.
Herdr's import-from-derivation requires a native Darwin builder even during
evaluation, so Linux cannot certify this check. The CI job uses ARM64 macOS 27
through GitHub's `xcode-27` runner image. After installing Nix, it resolves the
documented `/Applications/Xcode_27.2.app` alias to its real application and runs
`hey xcode-setup` to prepare Metal and select it, then checks `metallib`. The
current image provides 27.2 as a release candidate with multiple symlink aliases.
CI's default 27.1 failed Metal discovery as a Nix build user even with
the component installed; uncached and SDK-independent lookup also failed.
After selection, it removes only inactive Xcode application directories to leave
room for the host builds. It resolves the selected toolchain's real path and
preserves that application and all application symlinks; it does not clean
developer machines or the NUC. Hex still requires the full host toolchain.
A separate Nix derivation checks tool discovery and runs Metal as a build user,
with the host SDK selected. Failures print the component status and raw tool
errors before the expensive host builds; runner-user success is not sufficient.
The required `Flake Check (Linux)` and `Check Formatting` compatibility contexts
require successful planning, Linux checks, and every selected platform job.
Failure, cancellation, missing results, or an unexpected skip fails both contexts.
An unselected platform job must be skipped. Native Darwin is required only when
explicitly requested; branch protection and exact-main NUC deployment guards
stay unchanged.
Native checks do not repeat the portable formatting/lint suite.
The Linux and Darwin validation jobs read private flake inputs with the
`NIX_PRIVATE_GITHUB_TOKEN` repository secret. Linux display tests need the pinned
private `tnote` source too. Use a fine-grained token with read-only Contents
access to `tnote` and `agents-workspace`. Do not reuse the write-capable Renovate token.
Both jobs also use the `REX_TOKEN` repository secret to fetch the private Rex
snapshot. Each validation step writes a mode-0600 temporary netrc file for
`pkgs.superlogical.com`, sets Nix's `netrc-file`, and deletes the file on exit.
The NUC's agenix credential does not supply credentials to GitHub runners.

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

Pi workspace manifests and lock/config changes select every package.
Package edits select that package and transitive workspace consumers, then run
their declared typecheck/test scripts and integration tests. Dependencies install
with the frozen lockfile inside the snapshot. `bin/qa-changed` is only a
compatibility shim for publication and older callers. `pkg-check <unit>` remains
separate: it clones upstream, applies carried patches and runs upstream tests.
`hey ztest` remains a focused interactive shell-test helper, not another CI suite.

## Hooks and migration

Commit hooks retain fast formatting/lint. Shared agent instruction checks run
without installing a model harness.
Pre-push safety (identity, submodules, HA assertions, runtime drift), Beads sync,
and deployment guards remain separate from source validation. Commit/push hooks
can mutate supported state; `hey check` does not run those stages.

Claude Code plugins and their validators are removed. If the retired
`Validate Claude Code Plugins` status was required in GitHub settings, an
administrator must remove that requirement before merging; deleting source
does not change branch protections. Re-enter the dev shell to regenerate
installed Git hooks; restart existing Codex sessions to unload old stop hooks.
Generated OpenWiki pages and historical worklogs are not workflow authorities.
