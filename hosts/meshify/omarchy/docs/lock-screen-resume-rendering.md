---
purpose: Record meshify's apparent password-input failure after suspend and the evidence for stalled lock-screen rendering.
applies_to: Omarchy lock screens that accept typing on a fresh lock but appear to require a click after resume.
entrypoint: Read the observations and upstream evidence before changing password focus or installing a resume workaround.
verification: Confirm visible typing after an authorized suspend/resume cycle without pointer movement; never capture real password keycodes.
update_when: A workaround is tested on meshify, installed versions change, or upstream identifies a fix.
---

# Lock screen appears to ignore typing after resume

Research date: 2026-09-27. The symptom remains unresolved. Stalled rendering is
the leading explanation, not a confirmed diagnosis on meshify. A post-resume
renderer reload was installed on 2026-10-19 with the user's approval. On
2026-10-21, the user reported that the symptom persisted with it installed.

## What happened on meshify

The user could type into a freshly opened lock screen without clicking. After
`systemctl suspend` and wake, they reported needing to click the password field.
We did not establish whether those earlier keystrokes were lost or merely
invisible.

Installed packages during the investigation:

| Package        | Version              |
| -------------- | -------------------- |
| hyprland       | 0.56.2-1             |
| hypridle       | 0.1.8-1              |
| omarchy        | 4.0.0-1.2            |
| quickshell-git | 0.3.0.r20.g28771c7-1 |

The custom `edmundmiller.lock` password view was identical to the installed
stock view. Its service differed only in the blanking timeout: thirty seconds
instead of five. Switching to stock would therefore not change the password
focus implementation examined here.

An experimental patch called `forcePasswordFocus()` when the Qt window became
active. A synthetic Qt test passed with that patch, but the user's real
suspend/resume test still failed. The patch and test were removed, and the
original live view was restored. Do not treat that synthetic test as evidence
that the actual bug was fixed.

## The upstream trace shows input arriving without a redraw

[Hyprland issue #16105](https://github.com/hyprwm/Hyprland/issues/16105), filed
2026-09-01, reports the same Hyprland revision with Omarchy and Quickshell.
The reporter's Wayland trace shows:

1. Hyprland sends keyboard focus and key events to the lock client after resume.
2. The client makes no new surface commits while the user types.
3. Pointer motion is followed by a pending frame callback, then surface commits.
4. The previously typed password dots appear together.

That trace supports a rendering stall in the reporter's session. It does not
prove the same cause on meshify or identify which component originally lost
the rendering progress. The issue was automatically closed under Hyprland's
issue-intake policy, not marked fixed by a maintainer.

[Discussion #15590](https://github.com/hyprwm/Hyprland/discussions/15590)
describes similar stale lock rendering on Hyprland 0.56 and 0.56.1 with
hyprlock. Its author reported an apparent recovery on August 3, then reported
the problem again after a clean installation on August 11. The different
hardware and lock client make this supporting evidence for the symptom, not
proof of an identical root cause.

As of the research date, GitHub's latest-release API still returned
[v0.56.2](https://github.com/hyprwm/Hyprland/releases/tag/v0.56.2), published
August 5. The investigation found no confirmed later fix specifically for
this report. Recheck upstream before recommending an upgrade as a solution.

## A post-resume renderer reload is an unverified workaround

The issue author reports that running `forcerendererreload` several times
after logind announces resume restores rendering. They provide neither an
exact watcher implementation nor controlled evidence for the required timing
or number of retries.

The [v0.56.2 dispatcher implementation](https://github.com/hyprwm/Hyprland/blob/v0.56.2/src/config/shared/actions/ConfigActions.cpp#L1197-L1214)
reapplies monitor rules across outputs. This is broader than requesting one
repaint and can cause visible flashing or output reconfiguration. Start with
one delayed invocation if testing this workaround; add bounded retries only
if observations justify them. An arbitrary one-second delay is not an
upstream ordering guarantee.

The existing [`hypridle.conf`](../config/hypr/hypridle.conf) is the place to
configure a future workaround. At investigation time, both the repository and
live configuration lacked `general.after_sleep_cmd`. The
[official hypridle documentation](https://wiki.hypr.land/Hypr-Ecosystem/hypridle/)
defines that option for the post-sleep D-Bus event, so no separate logind
watcher is needed.

After the user reported recurrence with Omarchy 4.0.4-1, Hyprland 0.56.2-2,
and hypridle 0.1.8-2 installed, the repository configuration was updated to
run one renderer reload one second after resume. It uses the installed
Hyprland Lua dispatcher, `hl.dsp.force_renderer_reload()`.

On 2026-10-19, the user authorized installation and a hypridle restart. The live
configuration now matches the repository, and `omarchy restart app hypridle -q`
replaced the existing process with exactly one running instance. The journal
showed successful startup with no reported configuration errors. No suspend or
renderer reload was triggered during installation.

### The first deployed workaround did not resolve the symptom

On 2026-10-21, the user reported another failure. The live configuration still
matched the installed workaround, exactly one hypridle process was running,
and a read-only Lua query confirmed that `hl.dsp.force_renderer_reload` exists.
However, that process's stdout and stderr both pointed to `/dev/null`. There
was no record proving whether the resume command ran or what it returned.

The journal recorded system resume at 19:30:44 America/Chicago, a later power
button event at 19:37:06, keyboard device detection at 19:37:14, and unlock at
19:37:18. This suggests a resume-only hook may precede the user's interaction
by several minutes. It does not prove why the display needed a click.

The repository hook now logs a start marker and the dispatcher's stdout/stderr
under `omarchy-resume-render`, without keyboard events or password data. It
still attempts only one reload after one second. Success and failure output
forwarding were checked with fake commands; all 19 lock/recovery tests passed.
Deployment of this diagnostic revision is pending because an Omarchy system
update was actively installing a kernel. The live hook still lacks logging.

After installing the diagnostic revision, inspect the next normal wake with:

```bash
journalctl -b -t omarchy-resume-render --no-pager
```

Correlate the start marker and dispatcher response with system resume and
unlock timestamps before adding retries or claiming a focus/rendering cause.

The previous configuration is backed up at
`~/.local/state/meshify-omarchy/backups/lock-resume-20261019T185740/hypridle.conf`.
To roll back with authorization, remove `after_sleep_cmd` from the repository,
restore that backup to `~/.config/hypr/hypridle.conf`, and run
`omarchy restart app hypridle -q`. No password-view changes are involved.

The documentation's example enables display power after resume. That does not
establish a fix for stalled frame callbacks when the display is already on.
Meshify's installed `omarchy-brightness-display on` deliberately skips its DPMS
dispatch when all active displays are on. Its comment warns that redundant
enabling can cause a resume-time flash. Do not edit that package-owned script
to implement a persistent workaround.

## Continue without exposing passwords or disrupting the session

- Get authorization before another suspend test, installing a workaround, or
  restarting the idle service. Coordinate wake and unlock with someone at the
  machine.
- If the owner agrees, check whether typing and pressing Enter unlocks the
  session without pointer movement even when no dots appear. That would
  support input delivery despite stalled rendering.
- Never capture raw Wayland keyboard events while entering a real password.
  Keycodes can reveal it. Use harmless test input or focus/render metadata.
- Follow the [locked-plugin reload warning](plugin-reload-lock-crash.md) before
  changing anything in the watched live plugin directory.
- Verify a proposed workaround with actual suspend/resume and visible typing
  before pointer movement. Record whether it causes flashes, delayed redraws,
  or monitor changes. Passing a QML focus test alone is insufficient.

The investigation and user-observed test results are in the
[Amp thread](https://ampcode.com/threads/T-01a0e0c0-905d-701f-b278-aff5bafcf39d).
