# worktree-manager

Nix package for upstream `jarredkenny/worktree-manager` (`@jx0/wtm`).

## Purpose

Provides the `wtm` CLI that jmux expects for its bare-repo worktree flow (`C-c n` -> `+ new worktree`).

## Packaging notes

- Source is fetched from GitHub in `default.nix`; upstream source is not vendored into this repo.
- Built with `bun build index.ts --target bun --format esm`.
- Installed as a wrapped `wtm` executable that runs via the Nix-provided Bun runtime.
- Wrapper prefixes `git` into `PATH` because `wtm` shells out to git for all worktree operations.

## Validation

Typical smoke test:

```bash
nix build .#packages.aarch64-darwin.worktree-manager
./result/bin/wtm help
```
