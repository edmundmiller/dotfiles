---
name: nix-package-patching
description: This skill should be used when the user asks to "bump a package", "update an upstream revision", "refresh a Nix source hash", "rebase local patches", "carry fork changes as patches", "hack on upstream software in this repo", or fix a package whose patches no longer apply.
purpose: Maintain pinned upstream software and small local patch stacks in this dotfiles repository.
applies_to: Packages under packages/ and patched overlays under overlays/.
update_when: Package discovery, package-harness, patch policy, or repository validation commands change.
---

# Nix package patching

Treat `packages/AGENTS.md` or `overlays/AGENTS.md` and the target's nearest `AGENTS.md` as authoritative. Use this workflow to bump upstream software, develop local changes against real source, and preserve those changes as reviewable Nix patches.

## Start from the declared package

1. Enter the repository development shell when `pkg-list` is unavailable:

   ```bash
   nix develop
   ```

2. Run `pkg-list`. Select the exact package or overlay unit. If the target is absent, inspect whether it lacks `package-harness.json`; treat missing metadata for an upstream patch stack as a maintainer gap rather than skipping fresh-source checks.
3. Read its `default.nix` or `.nix` definition, adjacent `package-harness.json` when present, patch list, checked-in lockfiles, and nearest package guidance.
4. Record the current upstream URL, revision, version, source hash, dependency hash, patch order, and build attribute.
5. Inspect upstream release notes and the target revision before editing. Check whether upstream already absorbed any local patch; delete redundant patches instead of rebasing them.

Never edit a fetched Nix store source. Reconstruct a writable upstream checkout at the exact pinned revision.

## Build a writable workbench

Clone or reuse a clean upstream checkout outside the repository. Create a branch from the package's pinned upstream revision. Apply patches in the exact Nix order:

```bash
git apply --check /path/to/patches/0001-example.patch
git apply --index /path/to/patches/0001-example.patch
git commit -m "local patch: example"
```

Apply every patch as a separate commit. Run the upstream build or focused tests in this fully patched tree before adding new behavior. Make the requested software change as one or more small commits on top.

Prefer changing upstream source over compensating in `postPatch`, wrappers, or Nix shell text. Keep packaging-only adjustments in Nix when they do not belong upstream.

## Bump an upstream revision

1. Fetch the desired tag or commit.
2. Start a clean branch at the new revision.
3. Try each existing patch in order with `git apply --check`.
4. Drop patches already present upstream.
5. Apply clean patches unchanged.
6. Rebase conflicting patches one at a time:

   ```bash
   git apply --3way --index /path/to/patch.patch
   # Resolve only the conflict caused by this patch.
   git add <resolved-files>
   git commit -m "local patch: <intent>"
   ```

7. Run focused upstream tests after the complete stack applies.
8. Update `version`, `rev`, or tag in the Nix definition and `ref` in `package-harness.json` together.

Never combine a source bump with unrelated local behavior. Keep the bump, patch refresh, and new feature separable when review or regression isolation benefits.

## Export patches

Keep text-only source changes as plain unified diffs under `packages/<name>/patches/` or the overlay's patch directory. Preserve one intent per numbered patch and list patches explicitly in application order.

Export each rebased commit without commit-message mail headers:

```bash
git show --format= --no-ext-diff --no-renames <commit> > /path/to/0001-intent.patch
```

Then verify from a clean checkout:

```bash
git apply --check /path/to/0001-intent.patch
```

Use plain patches only for text changes that require neither rename metadata nor binary payloads. If correctness depends on renames or binary patches, follow the target package guidance and switch the packaging flow to `git format-patch --binary` plus `git am`; do not force that change through Nix's ordinary `patches = [ ... ]` path.

After splitting, deleting, or reordering patches, update both the Nix `patches` list and `package-harness.json`.

## Refresh hashes and lockfiles

Update hashes in dependency order:

1. Update the upstream revision.
2. Recompute the fetched source hash.
3. Regenerate a checked-in lockfile only when the upstream dependency graph or a local dependency patch changed.
4. Recompute `npmDepsHash`, pnpm dependency hash, Cargo hash, or equivalent from the fully patched source.

Use the repository's existing fetcher and lockfile pattern. Temporarily use the appropriate fake hash, run the narrow package build, and replace it with the exact `got:` hash from a genuine fixed-output mismatch. Change one unknown hash at a time so each reported hash maps to the intended fetcher.

Do not copy hashes between revisions, accept a hash from an unrelated failure, or regenerate lockfiles merely to silence a build.

## Declare fresh-upstream checks

Keep `package-harness.json` aligned with reality:

- `source`: canonical upstream clone URL.
- `ref`: exact tag or commit used by Nix.
- `patches`: ordered repository-relative patch paths.
- `checks`: focused upstream commands that prove the patched source works.

Run `pkg-check <unit>` before relying on a local build. It clones fresh upstream source, checks out the declared ref, applies the declared patches, and executes the declared checks. A local workbench alone does not prove the checked-in metadata can reproduce it.

## Verify the packaged result

Run the narrowest complete sequence:

1. `pkg-check <unit>` for fresh-checkout patch and upstream checks.
2. `nix build .#<package-attribute>` for the actual derivation.
3. Exercise the built executable or changed behavior from `./result`.
4. Run `ast-grep scan packages/` or the corresponding overlay scope.
5. Run the target package's focused tests and checks.
6. Run `hey check` for repository policy.
7. If the host consumes the package, rebuild through the repository's `hey` workflow and smoke-test the installed command.

For cross-platform packages, evaluate every declared platform and build on locally available platforms. Do not claim a Linux build passed when only Darwin evaluation succeeded. On Darwin, never evaluate `nixosConfigurations.nuc` directly.

Finish with a focused diff, one-intent commits, pull/rebase, push, and confirmation that the branch matches upstream. Leave unrelated worktree changes untouched.
