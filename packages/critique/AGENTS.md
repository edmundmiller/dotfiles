# critique

Nix package for **upstream** [remorses/critique](https://github.com/remorses/critique) with a small local patch stack that preserves the Pi-related work from the fork.

**Upstream fetched by Nix:** [remorses/critique](https://github.com/remorses/critique)
**Patch source:** exported from the former [edmundmiller/critique](https://github.com/edmundmiller/critique) fork

## How this package is structured

This package now uses the simplest possible source-layering model:

1. fetch upstream `remorses/critique` at the pinned base revision
2. apply local plain unified diffs via `patches = [ ... ]`
3. copy in a checked-in `package-lock.json` for the fully patched tree
4. build/package the resulting source with Bun at runtime

That means the fork itself is no longer required as a packaging input once the patch files are checked in.

## What the patch stack changes

The local patches currently preserve these fork behaviors:

1. **Pi review-agent support**
   - Adds `critique review --agent pi`.
   - critique talks to `pi-acp` alongside the existing OpenCode/Claude ACP paths.

2. **Pi session context support**
   - critique can discover Pi sessions from `~/.pi/agent/sessions/...`.
   - Session context can be listed/loaded even when ACP session listing is unavailable.

3. **JSONL fallback loading for normal Pi sessions**
   - If ACP cannot load a Pi session, critique falls back to parsing the Pi JSONL session files directly.
   - This is needed because many Pi sessions were not created through `pi-acp` and therefore cannot be loaded by ACP session ID alone.

4. **Git diff compatibility hardening**
   - Includes the `--no-ext-diff` adjustment so critique works in environments where external diff tooling would otherwise interfere with parsing.

5. **Small packaging-adjacent fix**
   - Keeps the `typecheck` script addition from the fork so `tsc` runs against the checked-in `tsconfig.json` consistently.

## Patch format expectations

The checked-in patch files are intentionally kept as **plain unified diffs** so they can be used directly in Nix `patches = [ ... ]`.

This only works safely because the exported commits met these conditions:

- text-only diffs
- no rename metadata required
- no binary patches
- applies cleanly with normal `patch` against the pinned upstream base revision

If future fork changes need git rename semantics or binary patches, switch from `patches = [ ... ]` to a `git format-patch --binary` + `git am` flow instead.

## Packaging notes

- critique still **runs on Bun**, so the wrapper launches the checked-in `src/cli.tsx` with `${bun}/bin/bun`.
- Dependencies are installed with `buildNpmPackage`, pruned to production dependencies, then shipped alongside the source tree so Bun can resolve runtime imports without carrying the full worker/test toolchain.
- Pi review mode still expects `pi-acp` to be available in the user environment.
- `public/` stays packaged because critique reads the bundled font assets at runtime for PDF/image generation.

## Updating

1. Re-export the fork delta as plain patches from the exact upstream base revision.
2. Verify the patches still apply with normal `patch`.
3. Update the upstream `rev` and `hash` in `default.nix` if rebasing to a new base.
4. Regenerate `package-lock.json` from the fully patched tree:
   ```bash
   npm install --package-lock-only --ignore-scripts
   ```
5. Recompute `npmDepsHash`.
6. Smoke-test with:
   ```bash
   nix build .#critique
   ./result/bin/critique --help
   ```
