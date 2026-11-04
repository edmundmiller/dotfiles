---
purpose: Repair Raycast updates that repeatedly fall back to Install Manually.
applies_to: Raycast stable on macOS when its updater launch service fails.
entrypoint: Toggle Raycast background activity off and on in System Settings.
verification: Complete an in-app update and verify the installer log and installed version.
update_when: Raycast updater registration, macOS settings, or recovery steps change.
---

# Repair Raycast auto-update

## Recognize the failure

Raycast downloads an update but repeatedly offers **Install Manually**, reports
an installation error, or times out. This runbook covers a broken updater
service registration, not every update failure.

Inspect the service from the affected user's session:

```sh
launchctl print "gui/$(id -u)/com.raycast.macos.updater"
```

The observed failure had `job state = spawn failed` and
`last exit code = 78: EX_CONFIG`. macOS repeatedly logged:

```text
Could not find and/or execute program specified by service:
3: No such process: Contents/Resources/Updater
```

The downloaded update passed its checksum, and
`/Applications/Raycast.app/Contents/Resources/Updater` existed, was executable,
and passed code-signature verification. This distinguished the failure from
a bad download or a read-only Nix-store installation.

## Reload the native updater service

This changes host background-service state and may restart Raycast during the
update. Agents need authorization before performing the repair. The Mac must
be unlocked to use the settings and Raycast UI.

1. Open **System Settings → General → Login Items**.
2. Find **Raycast** in the background-activity list, not the Open at Login list.
3. Turn it **off**, wait a couple of seconds, then turn it **on** again.
   Leave it enabled.
4. In Raycast, run **Check for Updates**, then choose **Install Update**.
5. Let Raycast finish installation and relaunch.

The off/on toggle made macOS reload the native updater job from the current
Service Management registration. It did not require a custom LaunchAgent,
manual app replacement, or a dotfiles rebuild.

## Verify installation, not just registration

Check the installed version:

```sh
/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' \
  /Applications/Raycast.app/Contents/Info.plist
```

Inspect the newest `raycast-updater-*.log` under
`~/Library/Logs/com.raycast.macos/`. It should record `Message: Successful update`.
The new main `raycast-x-*.log` should also confirm `Successfully updated`.
Read the newest logs rather than treating an older successful update as proof.

Run `launchctl print` again. An idle updater with `state = not running` and
`last exit code = 0` is normal after a successful installation. A listed job
alone does not prove it can execute.

If needed, test that the helper can still launch after the app replacement:

```sh
launchctl kickstart "gui/$(id -u)/com.raycast.macos.updater"
sleep 3
launchctl print "gui/$(id -u)/com.raycast.macos.updater"
```

Expect a running helper with a PID and a new updater log containing
`LaunchAgent has been started`, rather than another spawn failure.

## What did not fix it

- Refreshing the app's Launch Services registration alone did not help.
- Removing stale installer-volume registrations and ejecting an old installer
  did not complete the repair. Their role in the original failure was not proven.
- `launchctl bootout` removed the failed job but left Service Management
  considering it registered. Raycast then failed to connect to the missing
  service instead of recreating it. Do not use bootout alone as this repair.

Do not reset the entire macOS background-item database, clear Raycast user
data, or install a competing updater LaunchAgent for this symptom.

## Verified incident

On 2026-10-01, MacTraitor-Pro running macOS 27.0 build 26A428 successfully
updated Raycast from 2.5.2.0 to 2.6.0.0 through its built-in updater after the
background-item toggle. The installer exited with code 0, Raycast confirmed
the update on restart, and the helper launched again after app replacement.

The original cause of the stale registration remains unknown. Persistence
across a reboot and the next release was not tested. If the same failure
returns, capture the current launchd status and updater logs for Raycast
support; do not claim this procedure guarantees that it cannot recur.

Investigation and repair: [Amp thread](https://ampcode.com/threads/T-01a0f535-6a8d-7673-b602-f501f382bdaf).
