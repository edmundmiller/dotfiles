# TinyType

An experimental macOS autocorrect app built in this repository, not a Hex plugin.
It uses [Rune](https://github.com/anomalyco/rune), `rune-kit`, and the OpenCode
theme, following [Hex's](https://github.com/anomalyco/hex) split between Rust UI
state and a native macOS host. Rune is pinned in `Cargo.toml` and `Cargo.lock`.

[TinyFix](https://github.com/cfahlgren1/tinyfix) supplies English spelling and
context corrections in careful mode. For example, it changes "a letter form
the bank" to "a letter from the bank" while leaving "fill out the form" alone.
This prototype runs TinyFix's published JavaScript engine in a persistent Node
child process rather than reimplementing its candidate scoring in Rust. Node,
ONNX Runtime's WASM files, and the model ship inside the app. No server or
first-launch downloads are required.

## Approved icon

The app uses the approved TinyFix Insert artwork for its Finder/Dock icon and
menu-bar symbol. The app name, executable, bundle identifier, and signing
identity remain TinyType's. Icon integration does not rename the app.

The original `TinyFix.icns` and black-alpha `TinyFixTemplate.png` / `@2x.png`
live under `app/`. Both local and Nix builds copy them into the bundle before
signing. AppKit loads the menu image at 18 points with both resolutions and
template tinting, so macOS supplies its light/dark appearance. The menu retains
the TinyType accessibility label and tooltip. Unbundled development launches
fall back to the existing `Tt` title if the image cannot be found.

Assets are copied without resizing, masking, or flattening from the approved
[Insert handoff](https://ampcode.com/threads/T-01a2001e-50d2-7235-8c64-b57acaadf27a).
The source `TinyFix-Insert.zip` has SHA-256
`9b2c92baf2c39904b8f999299af6158d591d3b70db7bcf9189feb603b823a730`.
See the [brandbook](https://ampcode.com/artifacts/tinyfix-brandbook-13160279-ddc7-4015-bd60-c23e8c9b1609)
for the approved geometry and palette. No font or wordmark is bundled.

## Behavior and boundaries

- Autocorrect starts paused on every launch. The sentence playground works
  without Accessibility access. Closing the window leaves the menu bar running.
- Live correction works across apps that expose editable text and a writable
  selection through macOS Accessibility. There is no app allowlist. TinyType's
  own playground is excluded. Secure fields and secure event input are skipped.
  Custom editors, terminals, and other controls without the required text and
  selection capabilities are skipped rather than edited blindly. This is not
  a guarantee that every input in every app works.
- The helper requests Accessibility activation for Chromium and Electron apps,
  following [Harper Desktop's approach](https://github.com/Automattic/harper/tree/master/harper-desktop/src-tauri/src/mac_broker).
  It restores the prior activation setting on pause, helper exit, or inspecting
  another app when the app exposed that prior value.
- Once enabled, the host samples focused text every 250 ms. It only considers
  observed additions at the caret, including in the middle of a field, after a
  900 ms typing pause. It checks up to four completed words before the caret and
  applies at most one change per pause. Text after the caret remains context,
  not a correction target. Open documents, deletions, selections, rewrites, and
  insertions larger than 32 UTF-16 units do not trigger corrections. A small
  paste can look like typing. Very fast typing immediately after focusing can
  be missed.
- The native helper checks permission, frontmost app, secure input, editable
  text role, available composition markers, selection, and a 16,384 UTF-16-unit
  field limit. It reads the whole eligible field as model context. This is not
  a keystroke-only interface. IME detection depends on attributes the app exposes.
- Before writing, the helper rechecks focus, exact text, and caret. It replaces
  the word plus the unchanged text between it and the caret with one
  process-targeted native Unicode typing event, never a whole-field AX write
  or the clipboard. The insertion ends at the intended caret without a second
  caret move that could redirect resumed typing. This commits browser editor
  state and fires its input handlers. Both spans, including that unchanged tail,
  must fit in 20 UTF-16 units. Longer spans and words after the caret are skipped.
  Like typing, retyping the tail can affect its rich-text formatting. The helper
  verifies the resulting text and caret and never resends an unconfirmed edit.
  Unconfirmed edits or undo pause the app. Accessibility cannot make these
  checks and writes atomic. A dispatched native edit can finish after pause or
  a focus change, including into another field of the same app.
- Option-Command-period pauses or resumes. Each toggle invalidates older
  inference results, including a pause followed quickly by resume.
- Option-Command-Z undoes the last correction only in the same field with its
  text and caret unchanged. The undone word is ignored until quit. Further
  typing invalidates this undo. Pause/resume clears the undo record. This is a
  separate shortcut. TinyType does not manage the target app's Command-Z stack.
- A confirmed correction shows a click-through chip with the old and new word
  and the undo shortcut near the changed word. Undo shows the reverse change.
  The chip follows macOS light/dark appearance, including changes while visible.
  It fades in over 120 ms and out over 180 ms after 4 seconds. Reduce Motion uses
  a static chip instead. It never activates TinyType or takes keyboard focus.
  Pause and focus changes dismiss it sooner. If the app exposes no word or caret
  bounds, the chip appears near the bottom of the pointer's display.
- Text, corrections, and ignored words stay in process memory. The app does not
  save or transmit them. The Copy button writes playground results to the
  clipboard only when pressed. An empty temporary lock file prevents duplicate
  instances and remains after quit. Helper errors pause correction.

## Build without installing

Apple Silicon macOS 15 or newer, full Xcode with Metal tools, Nix, Node 22 or
newer, and npm are required. The build script selects Cargo and Rust from the
repository's pinned `nixpkgs-jj` input, matching `default.nix`, without changing
the host toolchain. Downloading build inputs needs network access. Model
downloads are pinned and SHA-256 checked by `engine/models.json`.

From this package directory, with the toolchains on PATH:

```sh
bash scripts/build-app.sh "$PWD/../../.amp/in/tinyfix/TinyType.app"
```

The output must not exist. The script builds a development app by default.
Set `TINYTYPE_PROFILE=release` for an optimized app. Without
`TINYTYPE_SIGNING_IDENTITY`, it ad-hoc signs the bundle for previews. With a
Keychain certificate's SHA-1 fingerprint, it signs the app and each executable
using that identity. Neither mode installs, launches, registers a login item,
or grants permissions. A copied Nix Node runtime can still reference its Nix
store closure. The local build is not a notarized distributable.

`default.nix` also exposes `pkgs.my.tinytype` through the repository's package
discovery. It builds an optimized app using the pinned Rust toolchain and host
Xcode, like the Hex and Quill packages. It requires relaxed or disabled Nix
sandboxing, cannot build on Linux, and must not use remote builders or binary
caches. It is not enabled in any host configuration. New untracked source must
be included in the Git source before normal flake evaluation can see it.

## Dev install and restart

From this package directory:

```sh
bash scripts/dev-install.sh
```

This builds, certificate-signs, verifies, installs to `~/Applications/TinyType.app`,
registers it with Launch Services, and restarts TinyType paused. The playground
draft clears on restart. Signing and build failures leave the running app alone.
Replacement failures restore the previous app if the destination is empty.
It does not add a login item or reset any macOS permission.

The first install uses the sole valid code-signing identity in the login
Keychain. With several identities, select one with `TINYTYPE_SIGNING_IDENTITY`
using its SHA-1 from `security find-identity -v -p codesigning`. Later installs
reuse the identity recorded inside the signed app. An unavailable identity
fails the install instead of silently switching to ad-hoc signing. The private
key stays in Keychain, never in the repository or Nix store.

Ad-hoc signing ties a permission to an executable's hash. Changed builds have
different hashes. Certificate signing gives the app and native helper stable
designated requirements across rebuilds with the same identity. The signing
test checks that changed app and helper binaries still satisfy the preceding
build's requirements. This is not a guarantee of TCC permission retention on
every macOS version or after a signing-identity change.

The first migration from ad-hoc signing still needs one manual repair. In
System Settings, remove the stale TinyType row with the minus button. In
TinyType, choose Set up Accessibility and drag its app tile into the list,
then switch it on. Never reset permissions for other apps as a workaround.

## Try it

Open the built `TinyType.app` and use Check sentence first. Live correction
requires explicit permission through Set up Accessibility. macOS may list
TinyType or its bundled `focused-text` helper, depending on TCC attribution.
The button opens the Privacy & Security list with a floating drag guide like
Hex's. macOS 27 calls the list Device Control and Data Access; older versions
call it Accessibility. The tile carries the running app's actual bundle URL,
not a build-cache path or an image. Show in Finder is an alternative to dragging.
The guide closes when permission is granted, or can be dismissed
without granting it. Returning to TinyType updates the permission state without
automatically enabling correction. Use a disposable plain-text TextEdit document
first. Rebuilt ad-hoc signatures may require permission again.

Disable TextEdit's own automatic spelling correction while comparing results,
so its edits are not confused with TinyType's. Stop with the menu bar's Quit
TinyType command. Do not rely on this prototype for important documents yet.

TinyType checks Apple's global autocorrect preference every two seconds through
`NSSpellChecker.isAutomaticSpellingCorrectionEnabled`. This repository already
sets `NSAutomaticSpellingCorrectionEnabled = false` in its macOS defaults.
The settings window warns when Apple's autocorrect is on and shows off or
not checked otherwise. Keyboard settings opens the relevant System Settings
pane. TinyType does not change the preference. To change it manually, use
System Settings > Keyboard > Text Input > Edit > Correct spelling automatically.
Individual apps can override the global preference through Edit > Spelling and
Grammar > Correct Spelling Automatically, or use their own spellchecker. A
global preference check therefore cannot prove autocorrect is off in every app.
Red spelling underlines and inline predictions are separate settings.

## Checks

From this package directory:

```sh
cargo test --locked
npm --prefix engine test
xcrun swiftc -O -parse-as-library native/FocusedText.swift native/AccessibilityGuide.swift -o target/focused-text
python3 native/test_focused_text.py target/focused-text -v
```

With an existing Keychain certificate, run the signing regression without
installing an app or changing permissions:

```sh
TINYTYPE_SIGNING_IDENTITY=<certificate-sha1> bash scripts/test-signing.sh
```

The engine test requires `npm --prefix engine ci --ignore-scripts` and
`node engine/download-models.mjs engine/.models` first. It runs real offline
inference and covers contextual and spelling corrections, a correct-word
control, code and URL exclusions, UTF-16 ranges, ignored words, invalid requests,
and clean shutdown. Rust tests cover typing eligibility, UTF-16 word ranges,
playground dispatch, and pause generations. Native protocol tests do not grant
permission, activate other apps, or edit documents by default. Add `--gui` to
the Python command to compile and open a disposable AppKit/WebKit fixture.
This opt-in test requires existing Accessibility access, temporarily changes
focus, and sends native typing events only to its own fields. It checks edits,
DOM input events, UTF-16 caret positions, undo, selections, read-only fields,
and password rejection. It covers continued input before edit verification,
unchanged tails containing emoji, and both sides of the 20-unit span limit.
The on/off preference test uses Foundation's process-local argument domain,
without writing global macOS settings. It also checks that correction and undo feedback appear
without changing the frontmost app, dismiss automatically, and clear on pause.
The fixture is never bundled with the app.

Rune can render fixtures without starting the model, reading apps, registering
shortcuts, or requesting permissions:

```sh
target/debug/tinytype --snap /tmp/tinytype.png --scene corrected --theme dark
```

Scenes are `paused`, `apple-autocorrect-on`, `corrected`, `enabled`, and `error`. The enabled scene is a
visual fixture, not evidence of live edits. Live trials used existing runner
permissions and disposable inputs, never existing documents. They verified
replacement after an emoji, stale-text rejection, guarded undo, and rejection
of a second undo. Cross-app trials verified native replacement and undo in
WebKit and Helium's Chromium single-line, multiline, and contenteditable
inputs. Browser DOM values and input events confirmed committed edits;
read-only and password fields were rejected.

A rebuilt-app trial left misspellings unchanged while paused, then enabled
autocorrect through its real Accessibility switch. It corrected newly inserted
words inside native and WebKit fields while preserving the suffix and caret.
The trial inserted initial text programmatically rather than using physical
keys. IME handling, app-specific editors, global shortcuts, and first-time
permission flows still need live testing. Chromium compatibility does not
establish compatibility with every Electron editor.

Run `hey check packages/tinytype` from the repository root for repository policy.
