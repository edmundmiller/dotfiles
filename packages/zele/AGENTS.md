# zele

Nix package for **upstream** [remorses/zele](https://github.com/remorses/zele) with a small local patch stack preserving the fork-only changes from [edmundmiller/zele](https://github.com/edmundmiller/zele).

**Upstream fetched by Nix:** [remorses/zele](https://github.com/remorses/zele)
**Patch source:** exported from the former fork-only commits in [edmundmiller/zele](https://github.com/edmundmiller/zele)

## How this package is structured

This package follows the same upstream-plus-patches pattern as `packages/critique`:

1. fetch upstream `remorses/zele` at the pinned base revision
2. apply local plain unified diffs via `patches = [ ... ]`
3. copy in a checked-in `package-lock.json` for the fully patched tree
4. build the project with Bun/Prisma
5. package the built `dist/` output plus runtime dependencies

That makes the fork optional after the patches are checked in.

## What the patch stack preserves

The current patch stack contains exactly the fork-only changes that existed on top of the pinned upstream base:

1. **Nix flake/dev-shell docs**
   - Adds `flake.nix` and `flake.lock` to the upstream source tree.
   - Expands `AGENTS.md` with development guidance for working on zele under Nix.

2. **Browser opener hardening**
   - Prevents noisy spawn-error behavior when the local browser opener command is unavailable during OAuth login.

3. **OAuth client lookup fix**
   - Resolves OAuth clients by known key name as well as by raw client ID, preserving the fork’s auth behavior.

## Patch format expectations

The checked-in patch files are intentionally kept as **plain unified diffs** so they can be used directly in Nix `patches = [ ... ]`.

That is safe here because the exported fork delta met these conditions:

- text-only diffs
- no rename metadata required
- no binary patches
- applies cleanly with normal `patch` against the pinned upstream base revision

If future fork changes need rename semantics or binary patches, switch to a `git format-patch --binary` + `git am` flow instead.

## Build/package notes

- zele is built with the upstream `build` script, which runs Prisma generation and TypeScript compilation through Bun.
- `sqlite` is included in `nativeBuildInputs` because zele’s build regenerates `src/schema.sql` via `sqlite3`.
- `prisma-engines` binaries are injected explicitly so Prisma generation works inside the Nix build sandbox.
- The final package wraps `dist/cli.js` with Bun and ships `dist/`, `src/schema.sql`, and production runtime dependencies.
- Top-level devDependencies are removed after build so the package does not ship the full development toolchain.

## Updating

1. Re-export the fork delta as plain patches from the exact upstream base revision.
2. Verify the patches still apply with normal `patch`.
3. Regenerate `package-lock.json` from the fully patched tree:
   ```bash
   npm install --package-lock-only --ignore-scripts
   ```
4. Update `rev`/`hash` in `default.nix` if rebasing to a new upstream base.
5. Recompute `npmDepsHash`.
6. Smoke-test with:
   ```bash
   nix build .#zele
   ./result/bin/zele --help
   ```
