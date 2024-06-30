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
          name = "origin";
          url = "https://github.com/edmundmiller/dotfiles.git";
          branches.main.name = "main";
        }
      ];
    };
  };
}
