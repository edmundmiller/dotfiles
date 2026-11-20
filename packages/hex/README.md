# Hex with lazy microphone close

Pins the Rust app at `v3.4.0`, matching source and release resources. This
replaces the old 2.3.1 derivation. The host already uses `my.hex`;
no activation or changes to the installed app are required to prepare patches.

## Microphone behavior

Enable **Turn off the mic when not dictating** in Hex's settings. After a capture
finishes or is cancelled, the patched app keeps the open microphone warm for
30 seconds. A new capture resets the countdown. Pre-roll is available while
warm, but the first capture after closure still waits for the device to open.
The macOS microphone indicator remains visible during the grace period.

Startup stays cold in this mode. Selecting the mode while idle closes the
microphone immediately, and a cancelled or failed pending open is not kept
alive. Disabling the switch keeps the microphone ready continuously.
Existing settings are not migrated or changed automatically.

## Build requirements and ownership

Like `packages/quill`, this uses the host's Apple toolchain with
`__noChroot = true`, `preferLocalBuild = true`, and `allowSubstitutes = false`.
It requires full Xcode 26 or newer, including `swiftc`, `metal`, and `metallib`,
and Nix `sandbox = relaxed` or `false`. Command Line Tools alone do not suffice.
Do not serve this host-dependent build from a binary cache.

Prepare an existing Xcode without activating the host configuration:

```sh
mise run xcode:setup /Applications/Xcode.app --apply --prompt-admin
```

Without `--apply`, this previews the selection. The command completes first-launch
setup when the license is already accepted, installs missing Metal tools,
verifies the compiler without cached lookups, then selects Xcode.
It does not accept licenses on your behalf. If Xcode is inside a private home
directory, pass its current path and `--install-to /Applications/Xcode.app` to
move it somewhere Nix build users can reach. An existing destination is refused.
The command prints the previous developer directory for rollback; if the app
moved, move it back before selecting that old path. Home permissions stay intact.

Cargo dependencies are pinned and fetched by Nix. The matching, hash-pinned
release ZIP supplies compiled icons, the command SDK, experimental microphone
driver, and runtime libraries. The main executable is compiled from the patched
source and replaces the release executable. The resulting bundle is ad-hoc
signed, not Developer ID signed or notarized. macOS permissions may need to be
granted again. Login-item and Gatekeeper behavior require runtime validation.

Upstream's `HEX_LOCAL_BUILD=1` disables update checks and installation actions,
so it cannot replace the local patch with an upstream binary. This replaces
the old Sparkle patch. Update through Nix. Model downloads are unaffected.

The build patch disables Swift macro subprocess sandboxing only for this
Nix-managed build. The package also wraps dependency `swift build` calls with
`--disable-sandbox`, as Quill does, and gives SwiftPM writable cache directories.
Rust build dependencies remain unstripped to avoid the macOS 27 loader bug in
Rust 1.96. These build-time settings do not change the app's runtime permissions.

## Checks and activation

- `pkg-check hex` applies all patches to fresh pinned source, checks Rust
  formatting, runs the standalone timer tests, then the macOS audio-owner tests.
  The last step needs the Apple toolchain and Cargo dependencies. Use the repo's
  Nix Rust toolchain from `nixpkgs-jj`, as the package does, rather than the
  default toolchain. Hex 3.4 requires Rust 1.97 or newer:

  ```sh
  nix shell --inputs-from . nixpkgs-jj#cargo nixpkgs-jj#rustc --command python3 packages/package-harness/package_harness.py pkg-check hex
  ```

  The checks select Apple's C compiler and archiver. A GNU `ar` earlier on PATH
  can produce archives rejected by the Apple linker.

- `hey check packages/hex` checks repository policy.
- `nix build .#hex --no-link` builds and checks the package without activation.
- Once built, test cold start, rapid consecutive dictations, a capture longer
  than 30 seconds, Escape during opening, and idle indicator release. Inspect
  the Settings preview for the updated copy.

Host activation remains a separate, explicitly authorized `hey re`. Until a
successful build and runtime check, the patch and packaging are prepared but
the resulting app is unverified. A previous nix-darwin generation is the
rollback path after activation; retain the current app until testing succeeds.

Hex 3 uses the new `anomaly.hex` app identity. Settings, history, and models
remain in the shared `hex` Application Support folder, but macOS permissions
and the login item may need to be granted again.
