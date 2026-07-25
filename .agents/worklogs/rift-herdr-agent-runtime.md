# Worklog: rift-herdr-agent-runtime

Status: complete

## Objective

Package Rift declaratively and expose it only through Herdr's inherited agent PATH. Stop when the package builds, the CLI runs on APFS, existing Git/JJ workspace bindings remain unchanged, the Darwin configuration is rebuilt, and the focused commit is published.

## Decisions

- Pin the exact `dev` commit documenting and implementing `--copy-all`; release `0.0.9` failed runtime smoke because that agent-relevant option is absent.
- Add Rift to Herdr's launch PATH, not the general interactive package set.
- Do not add a Rift workspace action yet; this change only makes the primitive available for agent trials.

## Evidence

- Current host: `MacTraitor-Pro.local`, Darwin arm64 on APFS.
- Nixpkgs does not currently expose a `rift` package.
- Upstream `dev` resolves to `18ca9d199cfa0033e1adf63b1eb6625fab89478a`, which identifies itself as `0.0.10`.
- Red/green contract: `tests/test_rift_herdr_runtime.py` failed before package/runtime wiring and passes afterward.
- `pkg-check rift`: 66 upstream tests passed from a fresh checkout.
- `nix build .#rift`: packaged binary built successfully with its isolated test suite.
- APFS runtime smoke: initialized a temporary Git repository, created a `--copy-all` child retaining `node_modules`, verified detached `HEAD`, then removed and garbage-collected the child.
- Focused Python tests: 10 passed with 4 subtests.
- `hey check --worktree`: all Darwin checks passed.
- `darwin-rebuild switch --flake .`: activated successfully.
- Live proof: `~/.local/bin/rift` resolves to the packaged Nix store binary, `rift --help` succeeds, and generated `open-herdr.sh` prepends that same package to Herdr's PATH.
- `hey agent-audit-tests`: passed.
- `hey agent-finish`: package, repository, confidence, inventory, and drift gates passed; its installed Nix-store `agent-quality-tests` copy failed while initializing an unrelated temporary jj fixture. The same current-workspace test passed directly with `python3 -m unittest`.

## Reviews

- Plan review attempted with `hey agent-review plan --active-model-family gpt-5.6`; blocked before review by `RUNTIME: Authentication required`.
- Landing review attempted with `hey agent-review landing --active-model-family gpt-5.6`; blocked before review by the same authentication requirement.

## Feedback

None.

## Remaining work

None.

## Commits

- `feat(herdr): package Rift for agent trials`
