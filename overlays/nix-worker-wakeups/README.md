# Nix build-slot wakeups

Backport upstream commit `fba3f6e49bea5f6b7b5b75ab794e32afaabd5d26`
to the pinned Nix 2.35.1 component set. This fixes
[Nix issue 16005](https://github.com/NixOS/nix/issues/16005).

When another process finishes a shared store path, a waiting build can finish
without consuming a build slot. Nix 2.35.1 wakes slot waiters only when a slot
is released, so remaining goals can be stranded and `Worker::run` aborts.
The upstream fix schedules available slot waiters in the worker loop.

The overlay extends the existing component set, so the CLI, daemon, and
linked libraries use the same patched source. The version assertion requires
review when nixpkgs moves past 2.35.1. Remove this overlay when the pinned
release includes the upstream fix.

`pkg-check nix-worker-wakeups` checks fresh-source patch application and patch
whitespace. It does not compile Nix or reproduce the scheduler race. Build
`darwinConfigurations.Seqeratop.config.nix.package` separately and exercise
concurrent builds against a daemon using that package before claiming a live
fix. An existing daemon keeps its old code until an authorized `hey re`.
