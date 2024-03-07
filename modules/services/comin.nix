{
  config,
  inputs,
  lib,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.services.comin;
in {
  options.modules.services.comin = {enable = mkBoolOpt false;};

  imports = [inputs.comin.nixosModules.comin];
  config = mkIf cfg.enable {
    services.comin = {
      enable = true;
      remotes = [
        {
          name = "local";
          url = "/home/emiller/.config/dotfiles/";
        }

        {
          name = "origin";
          url = "https://github.com/edmundmiller/dotfiles";
        }
      ];
    };
  };
}
