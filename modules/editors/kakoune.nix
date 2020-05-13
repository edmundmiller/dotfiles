{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.editors.kakoune = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };
  config = mkIf config.modules.editors.kakoune.enable {
    my.home.programs.kakoune = {
      enable = true;
      config = {
        autoComplete = [ "insert" "prompt" ];
        autoInfo = [ "command" "normal" ];
        autoReload = "ask";
        # colorScheme = "";
        numberLines = {
          enable = true;
          highlightCursor = true;
        };
        ui = {
          enableMouse = true;
          assistant = "dilbert";
        };
      };
    };
  };
}
