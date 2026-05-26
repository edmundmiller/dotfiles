# Sleep Domain — Agent Reference

Owns the full sleep/wake lifecycle. See `README.md` for flow diagrams and `../../docs/adr/0001-alarm-driven-circadian-sleep-lifecycle.md` for the decision record.

## Files

- `default.nix` — Core sleep domain config (helpers, scenes, scripts, 8Sleep sync, wake tracking)
- `wake_up_at.nix` — Alarm-relative bedtime scheduler/homeostasis automation
- `README.md` — Human docs (flow diagrams, troubleshooting)

## Key Facts

- Owns: `input_boolean.goodnight`, `input_boolean.edmund_awake`, `input_boolean.monica_awake`
- Canonical bedtime lifecycle: Winding Down → Get Ready for Bed → Good Night → Sleep → Good Morning
- Circadian driver: Edmund's next iPhone alarm when Edmund is home; Monica's phone is future fallback when Edmund is away
- Timing model: 6 × 90-minute cycles by default; Winding Down = Sleep - 60m, Get Ready for Bed = Good Night - 10m, Good Night = Sleep - 15m
- Homeostasis check: every 5 minutes between 8 PM and midnight; apply each phase once per night using helpers
- Winding Down is soft circadian cueing only; do not set `input_boolean.goodnight` or hard-shutdown the house there
- Good Night is the in-bed settling phase; historical/voice aliases like “Ignite” and the old In Bed path are retired, not canonical terms
- Wake: detection automations set `input_boolean.*_awake`; Good Morning is manual/voice scene activation only
- Apple↔8Sleep: iPhone alarm syncs to 8Sleep; focus off dismisses 8Sleep alarm (6–9am)
- Per-person automations DRY'd via `mkSleepFocusOff` and `mkWakeDetection`
- All iPhone focus sensors are **generic** — no per-mode (Sleep/Work/DND) sensors exist
- 8Sleep bed presence is **unreliable** — do not use it to auto-fire Good Morning

## Cross-domain Touchpoints

- `modes.nix` `everything_off` currently delegates to Winding Down scene; revisit when Winding Down becomes soft-only
- `ambient.nix` Arrive Home scene sets `goodnight = off`
- `lighting.nix` AL sleep mode time triggers (10pm / 7am) may need to move from fixed times to circadian timing
- `conversation.nix` GoodMorning voice intent calls `scene.good_morning` directly
- `vacation.nix` reads `goodnight` state but doesn't modify it
