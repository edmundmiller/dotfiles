# callstack-diff

`src/cli.ts` owns the Bun/Effect 4 CLI; Oxc parses static JS/TS call trees.
`callstack-diff skill` gives usage. Resolution is name-based, not a sound call
graph: dynamic dispatch, re-exports, and collisions use first matches. Bare
calls prefer free functions; calls passed as arguments are not sibling expansions.

The canonical skill is `skills/catalog/callstack-diff/SKILL.md`; the package
symlink serves development and Nix copies that source into the package.

## Packaging

Sources run directly on Bun. `bun.nix` pins dependencies including native Oxc
bindings; regenerate with bun2nix when the lock changes. Pin `@types/bun` to a
concrete version. Vite/Vitest, oxlint, and Effect development tools are not
production dependencies. `bun run lint:setup` patches ignored node_modules after
installation; Nix uses `--ignore-scripts --production` and excludes that patch.

## Evaluation boundary

`bun run lint` and `bun run test` are deterministic checks. `bun run evals`
loads the suite but skips live cases without opt-in; `bun run evals:pi` uses a
live model. That lane disables discovered Pi configuration and gives only read
plus a package-owned tool executing the case's fixed command, not shell/edit/write.

Raw reports remain ignored/private. Promote only minimized public fixtures and
specific reproducible evidence to deterministic regressions; live complaints
supplement rather than replace those tests.
