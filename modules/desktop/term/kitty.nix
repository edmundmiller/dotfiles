# modules/desktop/term/kitty.nix

{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.term.kitty;
in {
  options.modules.desktop.term.kitty = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    # kitty isn't supported over ssh, so revert to a known one
    environment.shellAliases = { s = "kitty +kitten ssh"; };

    user.packages = with pkgs; [ kitty ];
  };
}
