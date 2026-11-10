---
purpose: Reproduce tinyTouch HID setup on personal and work Macs without copying credentials.
applies_to: MacTraitor-Pro and Seqeratop, using an already enrolled tinyTouch device.
entrypoint: Run hey tinytouch-setup, then hey tinytouch-setup --pair in Terminal.
verification: Check registered computers, the launchd helper, and a real password prompt.
update_when: The pinned CLI release, installer checksum, or pairing procedure changes.
---

# tinyTouch on macOS

The [setup task](../../bin/hey.d/tinytouch-setup) pins the official macOS CLI
and its installer checksum. The upstream installer verifies the architecture's
download against its release manifest and keeps the signed bundle under
`~/Library/Application Support/tinyTouch/`, with a command in
`~/.local/bin/tinytouch`. Both Apple silicon and Intel Macs use the same task.
It does not use Homebrew or repackage the helper in the Nix store.

## Install or restore a Mac

From this checkout, install the pinned release:

```sh
hey tinytouch-setup
```

If that exact CLI version already works, the task leaves it alone. Otherwise,
it installs the pinned release, even if a different version is newer. It does
not pair a device by default. The upstream installer may upgrade an existing
helper and request Keychain access when replacing a different CLI version.

Connect tinyTouch and run the interactive pairing step in a local Terminal:

```sh
hey tinytouch-setup --pair
```

Touch with an enrolled finger only when prompted, then enter **this Mac's login
password** in the hidden prompt. Approve macOS Keychain dialogs if shown. The
CLI saves the password and a per-Mac pairing key in the login Keychain and
installs `~/Library/LaunchAgents/com.tinytouch.helper.plist`. The helper starts
at login and launchd restarts it if it exits.

Pairing preserves fingerprints and existing computers, including Seqeratop when
adding MacTraitor-Pro. Repeating setup on a Mac reuses its saved pairing key.
The task skips fingerprint enrollment. For a new, empty sensor, enroll a finger
with `tinytouch enroll 1` first. Do not factory-reset an already paired device.

If multiple devices are connected, select one explicitly using its current path:

```sh
~/.local/bin/tinytouch ports --json
hey tinytouch-setup --pair --port /dev/cu.usbmodem103
```

Serial paths can change after reconnecting. No port, username, password, pairing
key, or biometric template is stored in the dotfiles. Run pairing separately on
each Mac. Do not copy Keychain items or the helper's runtime files between Macs.
Pairing is deliberately outside `hey re`; a rebuild cannot supply your password
or touch the sensor.

## Verify

```sh
~/.local/bin/tinytouch status --summary
~/.local/bin/tinytouch computers
~/.local/bin/tinytouch fingers
launchctl print "gui/$(id -u)/com.tinytouch.helper"
```

Expect HID mode, a ready sensor, the existing fingerprint inventory, and the
helper in `state = running`. On a fresh second Mac, the device gains one computer
without removing the original. Re-pairing the same Mac should not add another.
Logs are under `~/Library/Logs/tinyTouch/`. Brief suspension while a foreground
CLI command owns the serial port is normal; the helper should reconnect afterward.

Finally, focus a real password prompt and touch the sensor. Do not test in a
text editor, shell command line, or chat, because HID types the actual password
into whatever has focus. Automated status checks do not verify password entry.

## Maintenance and recovery

- After changing this Mac's password, run `tinytouch password` in Terminal.
- For Keychain access or helper installation problems, run `tinytouch repair`.
- `tinytouch uninstall` removes the helper but preserves credentials and device
  state. It does not remove the CLI.
- To update the dotfiles pin, review the chosen release's `install.sh`, change
  the version and SHA-256 together in the setup task, and rerun its checks.
  Update the version fixture in `tests/test_mise_tasks.py` at the same time.
- `tinytouch update` also updates device firmware. Keep firmware updates explicit
  and separate from this setup task. An upstream self-update can move the local
  CLI beyond the dotfiles pin; running the task restores the pinned CLI.

HID works in password prompts but is not equivalent to Touch ID. Upstream
documents physical attacks against the sensor's unauthenticated UART connection.
Meshify is deferred because the upstream helper and Keychain integration require
macOS; this task rejects Linux without making changes.

References: [upstream setup](https://docs.tinytouch.dev/customer/setup),
[CLI reference](https://docs.tinytouch.dev/reference/cli), and
[security trade-offs](https://github.com/ZimengXiong/tinyTouch#red-pill-or-blue-pill).
