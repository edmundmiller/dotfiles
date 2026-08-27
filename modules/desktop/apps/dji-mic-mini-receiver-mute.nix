{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.djiMicMiniReceiverMute;
  ruleSource = "${config.dotfiles.configDir}/karabiner/dji-mic-mini-receiver-mute.json";
in
{
  options.modules.desktop.apps.djiMicMiniReceiverMute.enable = mkBoolOpt false;

  config = optionalAttrs isDarwin (
    mkIf cfg.enable {
      home.file.".local/bin/dji-mic-mini-receiver-mute".source =
        lib.getExe pkgs.my.dji-mic-mini-receiver-mute;

      home.file.".config/karabiner/assets/complex_modifications/dji-mic-mini-receiver-mute.json".source =
        ruleSource;
    }
  );
}
