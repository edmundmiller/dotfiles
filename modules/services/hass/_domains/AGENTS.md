# HA domains

Domains are explicitly imported by `../default.nix`. Append automation/scene
lists with `lib.mkAfter`; scripts/helpers are attribute sets. Wrap automation
lists with `ensureEnabled` from `../_lib.nix`: final merged automations require
`initial_state = true`, enforced by `../_tests/eval-automations.nix`. UI toggles
are temporary, not durable enablement policy.

Scenes assert complete desired states; scripts own sequences/service calls;
automations own triggers/conditions. Dynamic waits, notifications, tracking,
and simple timed toggles need not be forced into scenes.

## Cross-domain contracts

- `sleep/` owns `goodnight` and per-person awake booleans. Ambient presence, TV,
  lighting, modes, climate, and voice intents consume them. Good Morning is
  manual/voice only; unreliable bed presence cannot trigger it.
- `vacation.nix` owns `vacation_mode`; ambient skips ordinary leave-home behavior
  during vacation. `modes.nix` owns guest/DND state and `everything_off`.
- Cleaning remains fail-closed: saved-map IDs are required before enablement;
  restored HA timestamps are not fresh iPhone verification. Preserve the bounded
  scheduler refresh/noon retry, arrival docking, and mission success tracking.
- Apple TV `start_off` stays enabled. `script.tv_on` connects `remote.living_room`,
  waits for availability, then powers on `media_player.living_room`. Every off
  path powers off the player before disconnecting the remote to avoid CEC wakeups.
- Adaptive Lighting manual takeover pauses adaptation for that light. Bedtime
  scenes enable sleep mode; Good Morning disables it, with a 7 AM hard cutoff.
  Current schedules/entity IDs belong in `lighting.nix` and the domain sources.

## Climate safety

`climate.nix` is the sole HA thermostat policy. Ecobee native Home/Sleep/Work
profiles are 72 F and Away 76 F on both thermostats, with native schedules as
fallback. Vacation is an explicit 78 F exception.

Precedence: Vacation → two-hour shared manual override → Away after two hours
→ Sleep → Home. GPS home or `Aviato` SSID is positive occupancy evidence;
ordinary Away requires all GPS/SSID signals away for two hours. Return by
either signal restores Home/Sleep immediately. Stale SSID home can delay savings,
not cause false-away cooling.

Transitions verify both thermostat readbacks, retry once, then notify through
`ecobee_climate_transition_failed`; no continuous drift correction. Authenticated
target changes apply to both thermostats for two hours with recorder-restored
helper target. Invalid core state or front-door pause clears both holds; door
close reapplies policy. Vacation end replaces its raw hold with the active profile.

## Checks

`hey nuc-wt build` prints the snapshot `NUC_WORKTREE_REMOTE_DIR`; on NUC, build
that snapshot's `.#checks.x86_64-linux.ha-automation-assertions`. Deployment and
live device actions need authorization and are separate from eval checks. The
`hass-declarative` skill covers manifests, entity identity, and orphan cleanup.
