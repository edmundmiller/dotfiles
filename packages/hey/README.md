# Bend `hey`

`hey` keeps the project-local mise interface. Native Bend controllers implement
its tasks; mise owns discovery, aliases, dependencies and the project environment.
Files in `bin/hey.d/` are thin shell entrypoints with mise metadata. They do not
contain Nushell implementations or a Nu fallback.

| Invocation                         | Executed command               |
| ---------------------------------- | ------------------------------ |
| `hey`                              | `mise tasks`                   |
| `hey help`, `hey -h`, `hey --help` | `mise tasks`                   |
| `hey help task args...`            | `mise run task args... --help` |
| `hey task args...`                 | `mise run task args...`        |

An empty first argument retains the old Bash `${1:-help}` behavior. Only the
first argument selects dispatcher help; later flags belong to the selected task.
The dispatcher preserves argument bytes, including non-UTF-8 filenames. Native
task text boundaries reject malformed UTF-8 rather than changing an argument.

## Task ownership

Family-specific `*-main.bend` programs parse arguments and sequence typed policy.
`default.nix` owns their installed names. The checkout's `bin/hey-task*` launchers
build this checkout's package, then execute the selected native program. Mise's
`MISE_PROJECT_ROOT` selects the checkout, not inherited `FLAKE_DIR` or `DOTFILES`.

Local C effects implement literal subprocess arguments, captured or inherited
streams, child-only environment changes, file-backed stdin and filesystem access.
They do not choose rebuild, deployment or publication policy. Remote shell workers
perform service/process/filesystem mechanics with Bend-selected commands, gates
and resource limits. Task entrypoints contain no orchestration shell bodies.

Evaluation and snapshot leases have affine handles. Failure cleanup remains
registered until a guarded handoff. An uncertain service submission retains its
snapshot lease because the remote unit may own it. Activation requires clean
source; NUC `build`, `vm` and `validate` accept dirty snapshots without activating.
These contracts have disposable Git, transport and privilege fixtures, not live
host-operation tests.

`hey agents:prepare` changes local pin files only. It does not commit, pull, push,
build on the NUC or activate a host. Publication follows candidate CI and requires
separate authority, as does deployment. See the
[NUC runbook](../../docs/runbooks/deploy-nuc.md).

## Checkout freshness

Before dispatch, `hey` checks the caller's dotfiles checkout against `origin/main`.
It fetches only main, at most once per 15 minutes across linked worktrees, with
a one-second timeout and no credential prompts. Advisory fetches skip Git hooks.
On timeout or cancellation, Git gets 200 ms to clean up before forced termination.
Other projects are ignored.
The cache lives at `hey-freshness` inside the common Git directory. Known stale
source produces a warning on stderr, including when an agent invokes `hey`.
An unsuccessful fetch uses the recorded remote ref and labels it cached.
If the cache is busy or unavailable, comparisons still run against cached refs
and active-system provenance without waiting for the cache or starting a fetch.
Missing Git, unavailable history, or a failed preflight never blocks the task.

`hey` never pulls, stashes, rebases, changes branches, builds a host, or activates
a system as part of this check. Clean main with no commits ahead of main gets an
explicit fetch and fast-forward command. Dirty, detached, feature, and diverged
checkouts get a warning to reconcile their work instead. Unknown ancestry in a
shallow clone is not treated as proof of divergence.

When active-system provenance records an ancestor of the checkout, a separate
warning reports how far that active revision trails the source. It reads Darwin's
`darwin-version.json` or NixOS's active `nixos-version --configuration-revision`.
NUC provenance uses the labeled `dotfiles` revision. Missing or dirty dotfiles
revisions are not guessed, and a `result` link is not evidence of activation.
This comparison still runs when remote main is unavailable or unrelated.
This does not check whether individual installed tools match their source.

Use `HEY_FRESHNESS=0` to skip the advisory. Direct `mise run` calls bypass it.
Existing installed versions need a one-time package update before they can warn;
using an updated checkout's `bin/hey` builds the new dispatcher without host
activation. Python is pinned by the package; Git comes from the caller's PATH.
The advisory uses isolated Python startup, ignoring settings such as
`PYTHONINSPECT` and `PYTHONPATH` without changing the eventual task's environment.

## Build and check

Nix pins Bend 2.0.40 and compiles the dispatcher and task programs to native code:

```sh
nix build .#hey
hey check packages/hey bin/hey.d
```

The package runs routing proofs and process, filesystem, policy and task acceptance
checks. Privileged, remote and hardware effects terminate at disposable fixtures.
Caller checks separately exercise mise discovery, aliases and the packaged Pi
updater. Passing these checks does not authorize or prove host activation.

The checkout's `bin/hey` builds the package in a child process, then replaces the
original shell with the native dispatcher. This keeps Nix's signal changes out of
the task process and preserves the caller's working directory. The installed
dispatcher does not invoke Nix or Bend; tasks still need their selected tools.

With Bend and clang on PATH, local dispatcher development is:

```sh
bend packages/hey/PROOF.bend
bash packages/hey/build /tmp/hey /absolute/path/to/mise
python3 -B packages/hey/test_hey.py
python3 -B -m unittest discover -s packages/hey -p test_freshness.py
```

`LAWS.bend` states only the pure dispatcher routing contract; `PROOF.bend` supplies
its proofs. They do not prove the compiler, C runtime, exec effect, mise or task
behavior. `--verdict` is a separate kernel check, not implied by ordinary C
compilation. Foreign task effects need behavioral tests.

## Dispatcher runtime boundary

Bend's built-in `Process.run` captures streams with limits and a timeout. The
exec-only dispatcher instead uses `exec.c` and POSIX `execv`, preserving inherited
terminals and replacing the process. Its mise executable is pinned to a store
path; runtime PATH does not choose it. PATH remains inherited for mise's tasks.
A missing executable or interpreter exits 127; other exec failures exit 126.

For this dispatcher, `launcher.c` evaluates synchronous argument-byte and exec
effects without the asynchronous event loop, its pipe or fault handlers. Ignored
dispositions, blocked signals and pending SIGPIPE survive exec. Runtime-parser
spellings such as `+RTS`, `--RTS` and `BENDRTS` remain task-owned.

The corpus initially reserves 512 MiB of virtual address space with a growable
allocator. The guarded dispatcher stack scales with argument count; task programs
use a larger base stack for policy evaluation. Virtual reservations are not
resident RAM. Dispatcher regressions cover a 1 GiB address-space limit and four
file descriptors without raising those limits. The C boundary uses version-specific
runtime APIs, so compiler upgrades require fresh boundary checks.

Mise owns task parallelism. Rebuilds, publication and activation must not be
reordered or duplicated to demonstrate Bend concurrency.
