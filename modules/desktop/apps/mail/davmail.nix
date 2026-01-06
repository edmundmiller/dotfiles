{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.mail.davmail;
in
{
  options.modules.desktop.apps.mail.davmail = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ davmail ];

    systemd.user.services.davmail = {
      wantedBy = [ "mbsync.service" ];
      script = ''
        /run/current-system/sw/bin/davmail ${config.users.users.${config.user.name}.home}/.config/dotfiles/config/davmail/davmail.properties
      '';
    };

    home.configFile = {
      "davmail" = {
        source = "${configDir}/davmail";
        recursive = true;
      };
    };
  };
}
