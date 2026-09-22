# Sleep lifecycle

`default.nix` owns helpers/scenes/wake tracking; `wake_up_at.nix` owns alarm-relative
scheduling. [README.md](README.md) and the
[ADR](../../docs/adr/0001-alarm-driven-circadian-sleep-lifecycle.md) explain the flow.

- Owns `input_boolean.goodnight`, `edmund_awake`, and `monica_awake`.
- Phases: Winding Down → Get Ready for Bed → Good Night → Sleep → Good Morning.
  Winding Down is soft cueing, not goodnight state or house shutdown.
- Edmund's Eight Sleep alarm while home drives timing. Ideal wake is alarm minus
  30 minutes; Sleep is six 90-minute cycles earlier. Winding Down is Sleep minus
  60 minutes; Good Night is Sleep minus 15 minutes; Get Ready for Bed is ten
  minutes before Good Night.
- Homeostasis checks every five minutes from 8 PM to midnight, once per phase
  per night. `sleep_homeostasis_test_tick` with ISO8601 `now` exercises the same
  actions, so firing it is not read-only verification.
- iOS next-alarm sync is disabled pending a helper/Shortcut bridge. Eight Sleep
  refreshes every two minutes from 7:30 to 11 PM while Edmund is home. Edmund's
  named Sleep Focus exit stops his Eight Sleep side from 6 to 9 AM; Monica retains
  generic focus-off handling.
- Wake signals set per-person booleans. From 7 AM to noon, Good Morning runs once
  every resident who is home is awake, but fails closed while Edmund's named
  Focus is `Sleep` or unavailable. Manual/voice Good Morning remains supported.

Consumers include ambient presence, `modes.nix`/`everything_off`, lighting,
climate, vacation, and the GoodMorning voice intent. Preserve their helper
contracts when changing phases; retired "Ignite"/In Bed aliases are not canonical.

Run `hey check modules/services/hass/_domains/sleep` and the parent HA automation
assertion for lifecycle changes. Treat `sleep_homeostasis_test_tick` as a live
action: use it only after deployment with explicit device-action authorization.
