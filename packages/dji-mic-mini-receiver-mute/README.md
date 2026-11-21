# DJI receiver mute

The DJI Mic Mini receiver's consumer-volume button runs `toggle` through the
device-scoped [Karabiner rule](../../config/karabiner/dji-mic-mini-receiver-mute.json).
Holding the button does not repeat the command.

## Commands

Run `dji-mic-mini-receiver-mute` with one of these commands:

| Command           | Result                                                                    |
| ----------------- | ------------------------------------------------------------------------- |
| `status`          | Read the receiver's input mute state. Also the default with no arguments. |
| `toggle`          | Switch between muted and live.                                            |
| `mute` or `on`    | Mute the input. Here `on` means mute is on.                               |
| `unmute` or `off` | Make the input live.                                                      |
| `--help` or `-h`  | Show help without requiring the receiver.                                 |

All changes share a process lock and wait up to 300 ms for CoreAudio to confirm
the requested mute state. Repeating `mute` or `unmute` when already in that state
does not write or play a sound. Invalid arguments never touch the receiver.

## Sounds and failures

- The native macOS `mic_mute.caf` cue confirms a change to muted.
- The native macOS `mic_unmute.caf` cue confirms a change to live.
- Sosumi reports a failed change, such as a disconnected receiver or a readback
  timeout. It does **not** mean the receiver is muted. Check `status` before
  retrying a toggle, since a timed-out write might still take effect.

The microphone cues play directly from macOS's internal system-sound directory,
`/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system`.
No audio files are bundled. These assets are present on macOS 27.2; their paths
are not a public API and may change in future macOS versions.
Sounds use the current system output and require audible output to be heard.
The helper does not change output volume or routing. Failure to launch a sound
after a verified change produces a warning, but the command still succeeds so
a caller does not retry and accidentally reverse the change.

The helper targets the exact receiver UID, name, and manufacturer in
`receiver-mute.swift`. It never changes the default input, output mute, Bluetooth,
or the transmitter's physical mute state. An app using another input is not
muted by this helper.

## Validation and installation

Run the focused regressions on macOS:

```sh
bash packages/dji-mic-mini-receiver-mute/_tests/test-feedback.sh packages/dji-mic-mini-receiver-mute
hey check packages/dji-mic-mini-receiver-mute
```

The host module installs the binary and Karabiner asset through Home Manager.
Source edits and package builds do not update the installed helper. Use the
normal authorized `hey re` workflow to activate changes. The existing enabled
Karabiner rule does not need to change for this version.
