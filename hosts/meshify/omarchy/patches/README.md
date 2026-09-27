# Amp default-agent backport

`6844-amp-default-agent.patch` carries the seven Amp-related files from
[Omarchy PR #6844](https://github.com/omacom/omarchy/pull/6844), pinned to
[988b3c8](https://github.com/omacom/omarchy/commit/988b3c8f146332fa9a11a1ab78bbe58420bf21d3),
against upstream `v4.0.0`. It includes the binary icon font and upstream tests.
Unrelated theme and manual differences between the tag and PR head are excluded.

Patch SHA-256: `334f77b1f203d28d0b7a3f6babfe26cb1226abc132f241b8520008786c8cf5ff`.

## Status and validation

The corrected package pair, `4.0.0-1.2`, is installed on Meshify. Both live and
tracked defaults are `amp`, and the manifest records the installed version.
The real launcher opened an Amp process in an `org.omarchy.agent` terminal.
The installed menu registers Amp with the selected-state predicate, and the
installed font includes `U+E908`. Menu refresh/summon IPC succeeded. The desktop
was locked during capture, so the rendered menu was not verified. No desktop
restart or unlock was performed.

The first pair, `4.0.0-1.1`, incorrectly copied source files created under umask
`0077`, leaving some desktop files root-readable only. Version `1.2` repairs
that mistake. `pacman -Qkk` reports zero altered files for `omarchy`; the only
three settings warnings are sudoers files this user cannot read. Hyprland
reports no configuration errors. Do not reinstall the superseded `1.1` pair.
This patch is not automatically applied by `manage restore`.

The corrected pair was rebuilt with readable source permissions and umask
`0022`. Direct archive metadata comparison, without extracting through the
runner's umask, confirms all payload modes, owners, types, and symlink targets
match the original release. Only the intended content changes remain.

From an otherwise clean Omarchy `v4.0.0` source checkout, set `patch` to the
absolute path of `6844-amp-default-agent.patch` in this directory, then run:

```bash
git apply --check "$patch"
git apply "$patch"
git diff --check
bash test/shell.d/default-agent-test.sh
bash test/shell.d/menu-test.sh
```

Both test files pass in the orb and on Meshify. They check default selection, installation
failure preserving the old default, PATH handling, literal prompt forwarding,
menu registration, and the font's Amp glyph. Installation is mocked; no Amp
installer is executed by these tests. The live Quickshell menu has not been
visually verified.

## Deployment boundary

Meshify inspection confirmed Linux `7.1.8-arch1-3`, packages `omarchy` and
`omarchy-settings` at `4.0.0-1`, `/usr/bin/omarchy`, and
`OMARCHY_PATH=/usr/share/omarchy`. The two agent scripts, menu, and icon font
match upstream `v4.0.0` byte-for-byte. There is no active development link.
Native Amp resolves to `~/.amp/bin/amp`, version `0.0.1790251618-ge05846`, with
an existing `~/.local/bin/amp` symlink. No Amp installer ran.

The dotfiles branch is `main`. Existing changes to `manifest.json` and
`local/share/` were preserved. Recheck this state before activation.

Do not apply directly to package-owned `/usr/share/omarchy`. Include this patch
in the installed version's package build or use a verified supported development
override. Keep a rollback package or the prior override configuration. Install
the matching scripts, menu, and font together; do not replace the running desktop
session merely to test an agent launcher. Package upgrades can remove a local
backport, so recheck compatibility rather than automatically reapplying it.

Once the patched runtime is active and `amp` resolves to the existing trusted
installation, `omarchy default agent amp` selects and launches Amp. If Amp is
missing, the upstream selector executes `https://ampcode.com/install.sh` through
Bash; inspect that installer before allowing a new installation. Update the
tracked `config/omarchy/defaults/agent` only after successful runtime validation.

To undo the patch in the isolated source checkout:

```bash
git apply --reverse --check "$patch"
git apply --reverse "$patch"
```

Host rollback instead restores the previous package or override and selects
`pi` again. Retire this backport once the installed upstream release supports Amp.

## Prepared package pair

The packages are under `~/.local/state/meshify-omarchy/amp-6844/packages/`:

| File | SHA-256 |
| --- | --- |
| `omarchy-4.0.0-1.2-any.pkg.tar.zst` | `2f2d1e5185f22557f4713caed26ede96845917c170e4721d6362f82c2f81b212` |
| `omarchy-settings-4.0.0-1.2-any.pkg.tar.zst` | `d8fdaed01d3829d37fe887d1d1991618aa86ba3907ffbfa69c0126eee5dc6beb` |

They use the official release recipes from
[omarchy-pkgs bb66b9d](https://github.com/omacom/omarchy-pkgs/commit/bb66b9dafc2eaa10cde9280e0094aed9382b9b0b)
and the patched `v4.0.0` source through the recipes' `OMARCHY_SRC` interface.
`6844-packaging.patch` records these adaptations:

- Increment the local package release to `1.2`, without upgrading Omarchy.
- Omit the settings install scriptlet, which otherwise overwrites unrelated
  `/etc` configuration on every upgrade.
- Preserve the release package's generated icons after verifying its hash.
  Regenerating them with this host's ImageMagick produced unrelated differences.

Payload comparison against the cached original packages found exactly two
changed agent scripts in `omarchy`. In `omarchy-settings`, only the menu, font
README, and two installed font copies changed. Package metadata changed and the
settings `.INSTALL` scriptlet was removed. Shell syntax checks passed. The
repository `hey` check could not run because its Nix shebang points at absent
`/run/current-system/sw/bin/nix` on this Arch host.

To reproduce, set `umask 022` before cloning isolated checkouts of those exact
upstream revisions. Apply the corresponding patches, and run
`OMARCHY_SRC=/absolute/patched/omarchy makepkg` separately in both recipe
directories, still under umask `0022`. Verify archive metadata directly against
the original packages, not just extracted files. The settings recipe requires
the original cached `omarchy-settings-4.0.0-1-any.pkg.tar.zst`. The current source
and build directories are `.amp/in/omarchy-amp-source` and
`.amp/in/amp-package-build` under the dotfiles checkout.

## Finish activation on Meshify

Unlock the existing desktop normally. In a local terminal, authenticate the
narrow transaction, without running a system update or the dev helper's broad
`--overwrite='*'` option:

```bash
state="$HOME/.local/state/meshify-omarchy/amp-6844"
sudo pacman -U "$state/packages/omarchy-4.0.0-1.2-any.pkg.tar.zst" \
  "$state/packages/omarchy-settings-4.0.0-1.2-any.pkg.tar.zst"
command -v amp
omarchy default agent amp
```

Then verify the launched Amp terminal, `omarchy default agent` reporting `amp`,
and the checked Amp entry and glyph in `omarchy menu summon setup.default.agent`.
Inspect a cropped menu capture without capturing private application contents.
Do not restart Quickshell just to test this. Only after successful runtime
validation, change tracked `config/omarchy/defaults/agent` to `amp` and the
manifest's expected Omarchy version to `4.0.0-1.2`, preserving its existing edits.

## Exact host rollback after activation

Original signed packages and the prior live `agent` file were copied to
`~/.local/state/meshify-omarchy/amp-6844/rollback/` before any activation.
Run from an unlocked local session:

```bash
state="$HOME/.local/state/meshify-omarchy/amp-6844"
install -m644 "$state/rollback/agent" "$HOME/.config/omarchy/defaults/agent"
sudo pacman -U --noscriptlet "$state/rollback/omarchy-4.0.0-1-any.pkg.tar.zst" \
  "$state/rollback/omarchy-settings-4.0.0-1-any.pkg.tar.zst"
```

`--noscriptlet` avoids the original settings package's unrelated `/etc` resets;
normal pacman hooks still run. Restore the tracked agent to `pi` and manifest
version to `4.0.0-1` if activation changed them.
