# Worklog: nuc-ups-monitoring

Status: complete (unpublished)

## Objective

Deploy NUT on the NUC as the sole owner of the CyberPower S175UC USB connection, shut the host down cleanly on `LOWBATT`, expose read-only telemetry to local Home Assistant, and document safe operation under `hosts/nuc`.

## Decisions

- NUT owns USB and host shutdown; Home Assistant reads the local NUT server without command credentials.
- NUT listens only on loopback and does not open the firewall.
- Use the UPS-reported `LOWBATT` condition rather than a guessed runtime threshold.
- Validate battery operation briefly without draining the battery or invoking UPS power-cut commands.

## Evidence

- Live USB discovery: CyberPower S175UC at USB ID `0764:0501`.
- `nut-scanner -U`: selected the `usbhid-ups` driver.
- Red check: `nuc-ups-monitoring` failed all absent-configuration assertions before implementation.
- `hey nuc-wt build`: built the complete NUC system closure with NUT and the HA NUT component.
- `nix build .#checks.x86_64-linux.nuc-ups-monitoring`: passed on the NUC after implementation.
- Live activation reproduced `nut_libusb_get_report: Input/Output Error`; a 15-second `usbhid-ups -x pollonly` probe initialized and polled cleanly, while the normal unit still failed afterward.
- The poll-only unit started cleanly after udev settled; encode that ordering and bounded startup retries for rebuilds and boots.
- Live restart chain proved `upsmon -> upsd -> upsdrv`; all three units returned active with `ups.status: OL` and stable telemetry over a 60-second sample.
- Home Assistant NUT entry loaded without credentials and exposed six live CyberPower entities.
- Rotated and redeployed the local monitor credential after an operator verification command displayed the prior value; the exposed value is no longer valid.
- Final readback: current and boot generations match, all NUT/HA units are active, and `systemctl --failed` is empty. Transient 1Password rate limiting made the switch helper return nonzero during activation, but existing values were preserved and the final activation result is successful.

## Reviews

No separate reviewer requested.

## Feedback

None.

## Remaining work

- Optional physical validation: unplug only UPS wall input for 10–15 seconds and confirm `OB DISCHRG`, then reconnect and confirm `OL`.
- Publication is pending explicit push/merge authorization.

## Commits

- `fe814f0ee` test(herdr): cover stopped runtime activation
- `10433a4d1` fix(herdr): defer activation without server
- `feat(nuc): add UPS-aware shutdown monitoring`
