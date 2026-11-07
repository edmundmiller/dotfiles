# Bend `hey`

`hey` retains the project-local mise interface. The rewrite covers argument
dispatch, not the Nushell tasks in `bin/hey.d/` or their guards in `bin/hey.d/.lib/`.
It neither activates a host nor changes which operations require approval.

| Invocation                         | Executed command               |
| ---------------------------------- | ------------------------------ |
| `hey`                              | `mise tasks`                   |
| `hey help`, `hey -h`, `hey --help` | `mise tasks`                   |
| `hey help task args...`            | `mise run task args... --help` |
| `hey task args...`                 | `mise run task args...`        |

An empty first argument retains the old Bash `${1:-help}` behavior. Only the
first argument selects help; later `--help` flags belong to the task. The
dispatcher preserves argument bytes, including non-UTF-8 filenames.

## Build and check

Nix pins Bend 2.0.40 and compiles `main.bend` to native code. `nix build .#hey`
runs the laws and process-boundary tests. The installed `hey` is the native
binary, with no second command name. All implementation, build, proof and test
files live here in `packages/hey/`.

The checkout's `bin/hey` builds this checkout's Nix package in a child process,
then replaces the original shell with the native binary. This keeps Nix's signal
changes out of the task process and preserves the caller's working directory.
It needs Nix and may build on first use. The installed `hey` needs neither Nix
nor Bend at invocation time. Use `nix shell .#hey` for repeated invocations
without the checkout launcher's Nix evaluation cost.

With Bend 2.0.40 and clang on PATH, local development is:

```sh
bend packages/hey/PROOF.bend
bash packages/hey/build /tmp/hey /absolute/path/to/mise
python3 -B packages/hey/test_hey.py
```

Run `bend PROOF.bend` from this directory before committing. `LAWS.bend` states
the routing contract and `PROOF.bend` supplies its proofs. These claims do not
prove the compiler, C runtime, exec effect, mise or host tasks. `--verdict` is a
separate kernel check, not implied by the normal proof command.

## Why there is a C boundary

Bend 2.0.40 has `Process.run`, but it supplies stdin and captures output with
limits and a timeout. `hey` needs inherited terminals, streaming output and
process replacement. `exec.c` calls POSIX `execv` with literal arguments. The
packaged binary pins mise's store path, as the previous package did. Development
builds take an explicit absolute executable path and use the same boundary.
Runtime PATH never selects mise; it remains inherited for mise's tasks. There
is no shell fallback or Bash-specific PATH interpretation. A missing executable
or interpreter exits 127; other execution failures, including executable text
without a shebang, exit 126. Tests use disposable executables, never host tasks.

`launcher.c` evaluates only the synchronous `IO.args_bytes` and exec effects.
It never starts Bend's asynchronous event loop, opens its pipe, installs fault
handlers, or ignores SIGPIPE. Inherited ignored dispositions, blocked signals,
and pending SIGPIPE therefore survive the dispatcher. It also bypasses the
runtime parser so `+RTS`, `-RTS`, `--RTS` and `BENDRTS` remain task-owned.

The CPU corpus initially reserves 512 MiB of virtual address space, retaining
Bend's layout and growable allocator. The evaluation stack scales with argument
count and has a guard page. This replaces roughly 10 GiB of default reservations
and passes the 1 GiB address-space and four-descriptor limit regressions without
raising either limit. Virtual reservations are not resident RAM, but this still
requires more address space than Bash. The C code uses version-specific runtime
APIs; compiler upgrades must pass the process-boundary tests before publication.

There is no useful independent work to parallelize in this dispatcher. It
transforms one argument list, then replaces itself with one mise process. Mise
retains responsibility for any task parallelism. Rebuilds, pushes and activation
must not be duplicated or reordered to demonstrate Bend concurrency.
