---
purpose: Install and operate Anomaly Spaceman with the former BSPWM workspace conventions.
applies_to: MacTraitor-Pro and Seqeratop on Apple silicon, macOS 14 or later.
entrypoint: modules/desktop/apps/spaceman.nix
verification: spaceman config-check config/spaceman/config.toml
update_when: Spaceman packaging, startup, workspace rules, or supported shortcuts change.
---

# Spaceman on the Macs

Both hosts enable `modules.desktop.apps.spaceman`. The package pins Anomaly's
signed, notarized release and exposes the `spaceman` CLI. Home Manager copies
the app to `~/Applications/Home Manager Apps/Spaceman.app`. A one-shot LaunchAgent
opens it at login without reconciling or removing other login items.
Do not install Homebrew's `spaceman` cask. It is an unrelated Spaces indicator.
The package pins `0.0.0-dev-226` to support the managed Labs and shortcut settings.
The configuration also selects Spaceman's `dev` update channel.

Before activation, run the affected `hey check` paths and `hey check --platform
darwin` on the exact candidate. Activation needs separate authorization and
uses `hey re` on each Mac. Quit any other window manager before opening Spaceman.
Open the copied app, finish its setup tour, grant Accessibility when prompted,
and press `Start Tiling`. macOS requires this grant on each machine; Nix cannot
grant it. Leave the app's own Launch at Login toggle off, since launchd owns startup.

## BSPWM conventions

Spaceman tiles automatically. The managed `[shortcuts]` modifier is
Control+Option+Command, called Hyper in Spaceman. It excludes Shift so adding
Shift selects move actions. Ordinary Command shortcuts remain available to Mac
applications.

| Action                               | Shortcut                            |
| ------------------------------------ | ----------------------------------- |
| Focus left/down/up/right             | Hyper+H/J/K/L                       |
| Move or nest tile left/down/up/right | Hyper+Shift+H/J/K/L                 |
| Switch workspace 1 through 10        | Hyper+1 through Hyper+0             |
| Send window without following        | Hyper+Shift+1 through Hyper+Shift+0 |
| Previous workspace                   | Hyper+Tab                           |
| Next tiled window                    | Hyper+`                             |
| Flip root split                      | Hyper+/                             |
| Shrink/grow focused tile             | Hyper+- / Hyper+=                   |
| Workspace-wide fullscreen layout     | Hyper+Shift+F                       |

On the ErgoDox, hold the Hyper key between Alt and Home. The Caps Lock-position
key remains Escape on tap and Control on hold.

Three-finger horizontal swipes switch Spaceman workspaces through
`labs.swipe_switch`. Managed macOS trackpad preferences reserve native Spaces
switching for four fingers and disable three-finger dragging. The configuration
sets `pause_on_builtin_display = true`, so Spaceman pauses on the built-in display;
workspace gestures do not act while paused.

All ten workspaces belong to the main display, extending the old BSPWM
primary-display convention. Helium and Ladybird start on 1, Amp Desktop and
T3 Code on 2, Rex on 3, and Slack on 4.
System Settings, mpv and VLC float. Bundle-only routes affect the initial app
window; secondary windows stay on the active workspace.

This is not exact BSPWM parity. The pinned dev build supports the configurable
shortcut modifier above. Fullscreen Layout applies to the workspace, not a single
BSPWM node. Move/nest is not guaranteed to be the old swap operation.

## Configuration and recovery

Edit `config/spaceman/config.toml` and rebuild. The deployed file is Nix-owned;
do not edit rules through Spaceman Settings. Package updates belong in
`packages/spaceman/default.nix`; a rebuild restores the pinned version even if
the copied app has updated itself.

Before a rebuild that replaces the app, including a package update or restoring
the pinned version after a self-update, pause Spaceman, quit it cleanly, and
confirm all parked windows have been restored. Do not replace the running bundle.
After activation, reopen `~/Applications/Home Manager Apps/Spaceman.app`.

Check the running agent with `spaceman ctl status`. Use `spaceman ctl pause`
before stopping it, or `spaceman ctl quit`, so it restores parked windows.
After a crash, reopen the same app and allow recovery. Never delete
`~/Library/Application Support/Spaceman/parked-windows.json` before confirming
restoration.
