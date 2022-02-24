# modules/dev/julia.nix --- Julia

{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.dev.julia;
in
{
  options.modules.dev.julia = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [ julia-bin ];

    # TODO
    # home.configFile = {
    # };
  };
}
