{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.git;
in
{
  config = mkIf (cfg.enable && cfg.ai.enable) {
    user.packages = [ pkgs.my.git-ai ];

    # Inject pi-git-ai package when pi is also enabled
    modules.shell.pi.extraPackages = mkIf config.modules.shell.pi.enable [
      "~/.config/dotfiles/pi-packages/pi-git-ai"
    ];
  };
}
