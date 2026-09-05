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
  refreshes every two minutes from 7:30–11 PM while Edmund is home; focus off
  dismisses its alarm from 6–9 AM. Focus sensors are generic, not mode-specific.
- Wake detection updates booleans only. Good Morning is manual/voice; Eight Sleep
  bed presence is too unreliable to activate it automatically.

Consumers include ambient presence, `modes.nix`/`everything_off`, lighting,
climate, vacation, and the GoodMorning voice intent. Preserve their helper
contracts when changing phases; retired “Ignite”/In Bed aliases are not canonical.
