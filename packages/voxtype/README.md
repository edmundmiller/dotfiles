# Voxtype native menu bar icons

`patches/0001-native-menubar-icons.patch` replaces Voxtype's macOS menu bar emojis with AppKit
template images using SF Symbols. Ready uses a microphone, recording uses a
waveform, transcribing uses three dots, and a stopped daemon uses a slashed
microphone. The images follow the menu bar appearance and keep a fixed status
item width. Tooltips and image accessibility descriptions include the state.

This is a manually installed macOS patch, not a Nix package override. NUC
activation does not install it. Homebrew's CLI remains unchanged, and running
the stock CLI's `setup app-bundle` overwrites the patched app.

This directory carries the patch and fresh-source checks only. There is no
Nix derivation or automatic host activation. Run `pkg-check voxtype` on macOS
from the repository development shell to validate a fresh upstream checkout.

## Source and build

The patch targets `peteonrails/voxtype` v0.7.5, commit
`8d49248baa53f29cb33007c9625a37281c72e799`. Apply it only to that revision, then
rebase and verify it when upgrading. It adds direct macOS dependencies already
present transitively in the upstream lockfile.

On MacTraitor-Pro, the original installed binary reported only `gpu-metal`.
The replacement retains Whisper with Metal acceleration. The existing config
selects `base.en`, the Fn hotkey, and typed output. Do not substitute a
default-feature build, which omits Metal, or change the user's engine/config
to accommodate a build.

From a clean checkout at the pinned upstream commit, with `DOTFILES` pointing
to this repository:

```sh
git apply --check "$DOTFILES/packages/voxtype/patches/0001-native-menubar-icons.patch"
git apply "$DOTFILES/packages/voxtype/patches/0001-native-menubar-icons.patch"
export CARGO_TARGET_DIR="$(mktemp -d)/target"
cargo test --locked --features gpu-metal
cargo build --locked --release --bin voxtype --features gpu-metal
"$CARGO_TARGET_DIR/release/voxtype" info variants
"$CARGO_TARGET_DIR/release/voxtype" transcribe tests/fixtures/vad/speech_hello.wav
```

Use a fresh target directory when changing feature sets. Verify the output
says `Hello world!` and the inference log says `using Metal backend`, not just
that the binary starts. Compare `info variants` with the installed app before
replacing it. A future installation with more engines needs matching build
features and any required libraries.

## Installation and recovery

App replacement requires explicit host-installation authorization. Back up
`/Applications/Voxtype.app` and the user's config first. Stage a copy of the app,
replace only `Contents/MacOS/voxtype-bin`, sign that executable and then the
bundle with `codesign --force --sign -`, and verify with
`codesign --verify --deep --strict`. Do not reset TCC or recreate the Login Item.

Wait for the daemon to be idle, stop the app and daemon, replace the bundle,
and reopen it with `open /Applications/Voxtype.app`. Confirm that the installed
executable matches the staged binary, the config/model checksums are unchanged,
and exactly one app and daemon are running. Verify file transcription again.
Allow time for the model and Metal library to load before checking daemon state.

Ad-hoc signing changes the code identity. If the log reports missing
Accessibility permission, re-enable Voxtype in macOS Privacy & Security.
Check Input Monitoring too if Fn capture still fails. File transcription does
not prove that microphone capture, Fn input, or text insertion works; verify
dictation interactively after granting permissions.

The 2026-10-28 installation retained the original signed bundle and config in
`~/Library/Application Support/voxtype/backups/20261028-native-menubar/`.
To roll back, stop the idle app and daemon, restore that `Voxtype.app` to
`/Applications`, verify its signature, and reopen it. Do not restore the config
over later user edits. The backup also contains the patch, source revision, and
binary hashes. These local backups are not stored in Git.

## Verification recorded for this patch

- The default-feature build and 790 upstream tests passed.
- The release build matched the installed `gpu-metal` feature set. Both old
  and new binaries transcribed the fixture as `Hello world!` with Metal.
- Native AppKit renders were inspected for all four states in light, dark,
  and highlighted appearances. The installed app was restarted successfully.
- Strict Clippy reported seven pre-existing warnings; they were not suppressed.
- Config and model hashes remained unchanged. Fn dictation still required the
  user's renewed Accessibility grant at the end of installation.

Implementation and installation evidence is in the
[originating Amp thread](https://ampcode.com/threads/T-01a182ea-3ea3-730c-904f-6327caace655).
