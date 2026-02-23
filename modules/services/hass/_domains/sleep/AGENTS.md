# Sleep Domain — Agent Reference

Three-stage bedtime flow + wake detection state machine. See `README.md` for full documentation.

## Files

- `default.nix` — All Nix config (scenes, automations, input_booleans)
- `README.md` — Human docs (flow diagrams, troubleshooting)

## Key Facts

- Bedtime: Winding Down (10pm) → In Bed (bed presence) → Sleep (manual)
- Wake: 5 signals per person feed `input_boolean.*_awake`; Good Morning fires when both on
- Apple↔8Sleep: iPhone alarm syncs to 8Sleep; focus off dismisses 8Sleep alarm (6–9am)
- All iPhone focus sensors are **generic** — no per-mode (Sleep/Work/DND) sensors exist
- 8Sleep bed presence is **unreliable** — treated as one signal among many, not authoritative

## Cross-domain Touchpoints

- Reads `input_boolean.goodnight` from `modes.nix`
- Sets `goodnight = on` via Winding Down
- Good Morning scene (in `modes.nix`) resets `edmund_awake` / `monica_awake`
- `lighting.nix` AL sleep mode mirrors `goodnight` toggle
