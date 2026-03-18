# Sleep Domain — Agent Reference

Owns the full sleep/wake lifecycle. See `README.md` for flow diagrams.

## Files

- `default.nix` — All Nix config (input_booleans, scenes, automations, scripts)
- `README.md` — Human docs (flow diagrams, troubleshooting)

## Key Facts

- Owns: `input_boolean.goodnight`, `input_boolean.edmund_awake`, `input_boolean.monica_awake`
- Scenes: Winding Down → In Bed → Sleep → Good Morning (full lifecycle in one file)
- Bedtime: Winding Down (10pm) → In Bed (bed presence) → Sleep (manual)
- Wake: 5 signals per person feed `input_boolean.*_awake`; Good Morning fires when all home residents awake
- Apple↔8Sleep: iPhone alarm syncs to 8Sleep; focus off dismisses 8Sleep alarm (6–9am)
- Per-person automations DRY'd via `mkSleepFocusOff` and `mkWakeDetection` helpers
- All iPhone focus sensors are **generic** — no per-mode (Sleep/Work/DND) sensors exist
- 8Sleep bed presence is **unreliable** — treated as one signal among many, not authoritative

## Cross-domain Touchpoints

- `modes.nix` `everything_off` script delegates to Winding Down scene
- `ambient.nix` Arrive Home scene sets `goodnight = off`
- `lighting.nix` AL sleep mode time triggers (10pm / 7am) complement scene-embedded toggles
- `conversation.nix` GoodMorning voice intent calls `scene.good_morning` directly
- `vacation.nix` reads `goodnight` state but doesn't modify it
