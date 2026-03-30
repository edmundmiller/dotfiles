# Skillkit Amp + Pi support

This repo keeps a small patch stack for `@crafter/skillkit` so the CLI can see:

- Amp session threads and skill usage
- Pi sessions, Pi skill directories, and the `--pi` filter

The patch is stored at:

```text
packages/skillkit/patches/0001-amp-pi-support.patch
```

## What is patched

The patch currently adds or updates these upstream files:

- `src/scanner/connectors/amp.ts` — Amp thread/session scanner
- `src/scanner/connectors/pi.ts` — Pi session scanner
- `src/scanner/index.ts` — wires Amp/Pi into scan/count paths
- `src/tui/args.ts` — adds `--pi`
- `src/scanner/skills.ts` — detects Pi skill directories
- `src/bin.ts` — help text for Amp/Pi filters
- `src/commands/scan.ts` — keeps scan output working when only sessions exist
- `src/scanner/auto-scan.ts` — allows session-only scans

## How it stays installed

The patch is applied by `bin/skillkit-sync`, which is also wired into Home Manager activation for hosts that enable `modules.shell.skillkit`.

The generated diff uses nested `a/a/...` and `b/b/...` paths, so the script
applies it from the package root with `patch -p2`.

That means:

- `darwin-rebuild` / `hey re` re-applies the patch automatically
- a manual reinstall of `@crafter/skillkit` can be repaired with `./bin/skillkit-sync`

## Fresh-machine setup

The normal macOS setup path is still:

```bash
./bin/hey re
```

If you want to rerun only the skillkit repair step after a reinstall/update:

```bash
./bin/hey skillkit-sync
```

## Updating when upstream changes

When a new upstream `@crafter/skillkit` release lands:

1. Reinstall the new upstream package you want to target.
2. Compare it with the currently patched install.
3. Regenerate `packages/skillkit/patches/0001-amp-pi-support.patch`.
4. Bump the pinned package spec in `bin/skillkit-sync` and
   `modules/shell/skillkit/default.nix` if you want the dotfiles-managed
   version to change.
5. Run `./bin/hey skillkit-sync` or `./bin/hey re`.

To regenerate the patch from upstream source, the pattern is:

```bash
npm pack @crafter/skillkit@<version>
# unpack, diff against the patched install, and overwrite the patch file
```

## Verification

After setup, these should work:

```bash
skillkit scan --amp
skillkit scan --pi
skillkit scan
skillkit stats --amp --days 30
skillkit stats --pi --days 30
```
