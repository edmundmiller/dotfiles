---
purpose: Record a working MacBook dock/display state and compare future failures.
applies_to: M3 Pro MacBook Pro with the CalDigit TS5 and ASUS/LG external displays.
entrypoint: Capture the failed state before reconnecting, opening the lid, or rebooting.
verification: Compare display modes, dock negotiation, lid state, power, and utilities.
update_when: Hardware, cabling, display modes, or a confirmed failure cause changes.
---

# MacBook dock display troubleshooting

## Known-good state

Observed on November 6, 2026 at 21:16 America/Chicago, while the user reported
both external displays working. This is one working configuration, not a claim
that every other mode fails or that the previous failure's cause is known.

| Item              | Observed working state                                                                          |
| ----------------- | ----------------------------------------------------------------------------------------------- |
| Laptop            | MacBook Pro, Apple M3 Pro with 18 GPU cores                                                     |
| macOS             | 27.2, build 26B123                                                                              |
| Dock              | CalDigit TS5, firmware 71.1, upstream micro firmware 1.18.0                                     |
| Host connection   | Thunderbolt/USB4 Bus 1, receptacle 2; TS5 in USB4 mode at 40 Gb/s; link status `0x2`            |
| ASUS XG32UCWMG    | Online, main display, 3840 × 2160; UI looks like 1920 × 1080 at 60 Hz; mirroring off            |
| LG Ultra HD       | Online, 2160 × 3840; UI looks like 1080 × 1920 at 60 Hz; rotation 270°; mirroring off           |
| Lid               | Closed: `AppleClamshellState = Yes`; `AppleClamshellCausesSleep = No`                           |
| Power             | AC power, battery charging; AC low-power mode off                                               |
| Display utilities | No process matching BetterDisplay, DisplayLink, Lunar, displayplacer, or SwitchRes was detected |

The internal display was not listed. The physical monitor-to-dock cable routing,
cable models, and monitor input selections were not recorded. Do not infer those
from the dock connection alone. The cause of the intermittent failure is not
confirmed; the comparison below records observations rather than a diagnosis.

The original raw capture is local and intentionally Git-ignored:
`.amp/in/display-diagnostics/working-20261106-211610.txt`. It is not available in
a fresh clone; the table above preserves its relevant observations in Git.
No background monitor is installed.

## Failed-state comparison, November 7, 2026

Captured at 10:31 America/Chicago after the user reported the dock not working.
The raw local file is `.amp/in/display-diagnostics/failed-20261107-103132.txt`.

- The LG Ultra HD was absent from the display list. The ASUS remained online as
  the main display at 3840 × 2160, with the same 60 Hz UI mode and mirroring off.
- The TS5 moved from Bus 1 / receptacle 2 to Bus 0 / receptacle 1. Its upstream
  link still reported USB4 at 40 Gb/s with link status `0x2`. Firmware was unchanged.
- macOS version/build, closed-lid state, AC power, power settings, and the lack
  of matching display utility processes were unchanged. The battery was charging.

This capture does not support a slower upstream dock link as the explanation.
The changed laptop port is a candidate to test, not proof of a defective port.
After preserving the failure, move only the dock's upstream cable back to the
previously working laptop port and capture again. Keep the other cables, monitor
inputs, and lid state unchanged. Recovery would still need a control: reconnecting
to the failing port also renegotiates the link and might recover independently
of which port is used. No recovery result has been recorded yet.

## Capture a failure without changing the connection

1. Before unplugging, changing ports, opening the lid, or rebooting, note which
   screen fails and whether it is missing, black but detected, flickering, or
   using the wrong resolution or rotation.
2. Note whether failure followed sleep/wake or docking. Record the approximate
   event time, lid state, laptop port, dock outputs, monitor inputs, and any cable
   changes. A photo of the cabling can help if taken without disturbing it.
3. Run the following on the affected Mac from the dotfiles checkout. It only reads
   system state and writes a timestamped local file. Use `state=working` for a new
   healthy capture; keep the original baseline rather than overwriting it.

```sh
state=failed
exclude=$(git rev-parse --git-path info/exclude)
if ! grep -qxF '/.amp/in/' "$exclude"; then
  printf '\n/.amp/in/\n' >> "$exclude"
fi
mkdir -p .amp/in/display-diagnostics
capture=".amp/in/display-diagnostics/$state-$(date +%Y%m%d-%H%M%S).txt"
{
  printf '=== %s dock/display capture ===\n' "$state"
  date -Iseconds
  sw_vers
  uptime
  printf '\n=== Displays and dock ===\n'
  system_profiler SPDisplaysDataType SPThunderboltDataType SPUSBDataType -detailLevel mini
  printf '\n=== Lid ===\n'
  ioreg -r -k AppleClamshellState -d 4 | rg 'AppleClamshell(State|CausesSleep)'
  printf '\n=== Power ===\n'
  pmset -g batt
  pmset -g custom
  printf '\n=== Display utilities ===\n'
  ps -axo comm= | rg -i 'betterdisplay|displaylink|lunar|displayplacer|switchres' || true
} > "$capture" 2>&1
printf 'Saved %s\n' "$capture"
```

Inspect the saved file for command errors or missing sections before treating
an absent device as evidence. Keep raw captures local; they can include device
identifiers. A blank utility section means no matching process was detected,
not proof that no display-related software is installed.

## Compare and narrow the cause

Compare the failed capture with the original local baseline, or a new working
capture produced by the same commands. Replace the failed filename below with
the one printed by the capture command. `diff` exit status 1 means differences
were found, not that capture failed.

```sh
diff -u .amp/in/display-diagnostics/working-20261106-211610.txt \
  .amp/in/display-diagnostics/failed-YYYYMMDD-HHMMSS.txt
```

- Check whether both displays remain online, with the same resolution, refresh
  rate, main-display assignment, mirroring, and LG rotation. A physically black
  screen can still appear online; record both observations.
- Check whether the TS5 appears under Thunderbolt/USB4 and whether its negotiated
  upstream speed remains 40 Gb/s. Distinguish an active link's `Speed` from an
  unused port's `Up to` capability. Note port and firmware differences.
- Check lid state, AC power, low-power mode, and newly running display utilities.
  Battery percentage, uptime, load average, and capture timestamps normally vary.
- If failure followed sleep/wake, save `pmset -g log` to a separate local file in
  the same directory and inspect entries around the recorded event time. The
  original baseline did not retain a comparable sleep/wake log.

Only after saving the failure evidence, try one recovery action at a time, such
as reconnecting the same cable to the same port. Record the action and capture
again if it restores the displays. Do not change ports, cables, refresh rates,
and lid state together and then attribute recovery to one of them.

If the system reports the same state during failure, that does not disprove the
visible symptom. The next investigation needs monitor input/cable evidence or
event-specific display logs, rather than assuming the dock link is responsible.
Update this runbook with a cause only after a failed/working comparison and a
focused reproduction support it. This laptop procedure needs no NUC deployment.
