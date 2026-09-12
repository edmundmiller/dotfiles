# DJI Mic Mini (mobile receiver) link button → Raycast dictation.
#
# Bedesqui's working path (bdsqqq/dots) is hidutil → F18 → Kanata virtual HID
# emitting Ctrl+Option+Command+Space for 120 ms. This repo already remaps the
# same receiver-scoped Consumer Control 0x0C/0xE9 through Karabiner's
# VirtualHIDDevice, so the Nix-managed piece is that chord — not a second
# Kanata stack. Raycast's dictation hotkey stays manual (encrypted SQLite).
{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.djiMicMiniRaycastDictation;
  ruleSource = "${config.dotfiles.configDir}/karabiner/dji-mic-raycast-dictation.json";
in
{
  options.modules.desktop.apps.djiMicMiniRaycastDictation.enable = mkBoolOpt false;

  config = optionalAttrs isDarwin (
    mkIf cfg.enable {
      assertions = [
        {
          assertion = !config.modules.desktop.apps.djiMicMiniReceiverMute.enable;
          message = "DJI Mic Mini receiver button cannot both mute and trigger Raycast dictation";
        }
      ];

      home.file.".config/karabiner/assets/complex_modifications/dji-mic-raycast-dictation.json".source =
        ruleSource;
    }
  );
}
