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

  # iOS notification icon backgrounds and glyphs, merged into data.data.
  # https://companion.home-assistant.io/docs/notifications/notifications-basic/#notification-icon-and-color
  notificationPalette = {
    home = {
      color = "#DCCCEC";
      notification_icon_color = "#4C2277";
    };
    climate = {
      color = "#BCD8EC";
      notification_icon_color = "#225477";
    };
    warning = {
      color = "#F9E1A8";
      notification_icon_color = "#8F680A";
    };
    success = {
      color = "#D6E5BD";
      notification_icon_color = "#577722";
    };
    pets = {
      color = "#FFCBE1";
      notification_icon_color = "#990041";
    };
  };
}
