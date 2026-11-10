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
