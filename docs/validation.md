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
