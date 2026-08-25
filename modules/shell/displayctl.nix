{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.displayctl;
  inventory = ../../packages/displayctl/config.json;
in
{
  options.modules.shell.displayctl = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.my.displayctl ];

    # These aliases make the declarative inventory discoverable to both humans
    # and agents while keeping all behavior in the JSON CLI contract.
    environment.shellAliases = {
      "busy-bar" = "displayctl busy-bar";
      "trmnl-og" = "displayctl trmnl-og";
      "trmnl-x" = "displayctl trmnl-x";
    };

    # Keep addresses and capability metadata versioned, while secret values
    # remain external environment inputs supplied by the host/agent runtime.
    home.configFile."displayctl/config.json".text = builtins.readFile inventory;
  };
}
