# Shared helpers for HA domain files.
#
# ensureEnabled: inject `initial_state = true` into every automation unless
# the automation explicitly sets `initial_state = false`.  Wrap any list of
# automation attrsets — works standalone or inside `lib.mkAfter`.
#
# Usage:
#   { lib, ... }:
#   let inherit (import ./_lib.nix) ensureEnabled; in {
#     services.home-assistant.config.automation = lib.mkAfter (ensureEnabled [
#       { alias = "My thing"; id = "my_thing"; ... }
#     ]);
#   }
{
  # Map over a list of automation attrsets, defaulting initial_state = true.
  # Individual automations can still override with `initial_state = false`.
  ensureEnabled = map (a: { initial_state = true; } // a);
}
