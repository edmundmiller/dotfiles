# LookAway Busylight / Luxafor integration

This repo supports two paths for driving the plugged-in Luxafor/Busylight from LookAway.

## Current meeting-detection path: launchd log watcher

LookAway's documented Automations only run at **break start** and **break end**. They do not currently expose a documented trigger for **meeting detected** or **meeting ended**.

For meeting detection, `hosts/mactraitorpro/default.nix` defines a user launchd agent:

- label: `org.nixos.lookaway-busylight`
- source attribute: `launchd.user.agents.lookaway-busylight`
- command: Nix Python with `busylight-for-humans`, running `bin/lookaway-busylight-monitor.py`
- stdout: `/tmp/lookaway-busylight.log`
- stderr: `/tmp/lookaway-busylight.err`

`bin/lookaway-busylight-monitor.py` tails:

```text
~/Library/Application Support/LookAway/Logs/LookAway-DebugLogs.txt
```

It watches for LookAway's meeting log transitions:

- start:
  - `HE Activity: Request received to pause with reason: meeting`
  - `Meeting detected on `
- end:
  - `HE Activity: Resuming pause with reason: meeting`
  - `Meeting not detected`

On start it launches:

```sh
busylight-status.py meeting
```

On end it terminates the meeting keep-alive process and runs:

```sh
busylight-status.py offline
```

The actual light control lives in `bin/busylight-status.py`. It prefers the current `JnyJny/busylight` Python API (`busylight_core`), with fallbacks for the older Python API and the `busylight` CLI.

### Useful commands

After `hey re`, inspect the launchd job:

```sh
launchctl print gui/$(id -u)/org.nixos.lookaway-busylight
```

Tail logs:

```sh
tail -f /tmp/lookaway-busylight.log /tmp/lookaway-busylight.err
```

Manual light tests using the Nix-managed Python environment from the launchd job:

```sh
python ~/.config/dotfiles/bin/busylight-status.py available
python ~/.config/dotfiles/bin/busylight-status.py meeting
python ~/.config/dotfiles/bin/busylight-status.py offline
```

If system Python does not have the dependencies, use the exact Nix Python from the active launchd plist or run after rebuilding.

## Documented LookAway Automation path: AppleScript

LookAway's documented automation path is Settings → Automation → Add Script. These scripts run on **break starts** or **break ends**, not meeting detection.

Use this path if you want the light to change during LookAway breaks.

### Start of break: turn the light on

Add this as a **Start of break** AppleScript automation:

```applescript
do shell script "/Users/emiller/.config/dotfiles/bin/busylight-status.py meeting > /tmp/lookaway-busylight-break-start.log 2>&1 &"
```

The trailing `&` is intentional: `meeting` mode keeps running to refresh the light, so AppleScript should not wait for it.

### End of break: turn the light off

Add this as an **End of break** AppleScript automation:

```applescript
do shell script "/Users/emiller/.config/dotfiles/bin/busylight-status.py offline > /tmp/lookaway-busylight-break-end.log 2>&1"
```

### If dependencies are missing from AppleScript's PATH

AppleScript runs with a minimal environment. If `busylight-status.py` cannot import its dependencies when launched from LookAway, use the Nix Python path from the generated launchd plist instead:

```applescript
do shell script "/nix/store/...-python3-...-env/bin/python /Users/emiller/.config/dotfiles/bin/busylight-status.py meeting > /tmp/lookaway-busylight-break-start.log 2>&1 &"
```

Prefer not to commit a hard-coded `/nix/store/...` path into docs unless needed; it changes after rebuilds.

## References

- LookAway AppleScript docs: <https://lookaway.com/docs/applescript/>
- LookAway Automations docs: <https://lookaway.com/docs/automations/>
- Busylight CLI docs: <https://jnyjny.github.io/busylight/cli/>
- Busylight source: <https://github.com/JnyJny/busylight>
