# modules/desktop/term/ghostty.nix
{
  config,
  inputs,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.term.ghostty;
in
{
  options.modules.desktop.term.ghostty = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = [ inputs.ghostty.packages.x86_64-linux.default ];
    # TODO alias ghostcopy = "infocmp -x | ssh YOUR-SERVER -- tic -x -"

    home.configFile."ghostty".source = "${configDir}/ghostty";
  };
}
