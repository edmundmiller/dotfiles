{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.desktop.apps.mail.aerc;
in
{
  options.modules.desktop.apps.mail.aerc = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      aerc
      (makeDesktopItem {
        name = "aerc";
        desktopName = "aerc";
        genericName = "Open a aerc in xst";
        icon = "mail";
        exec = "${xst}/bin/xst aerc";
        categories = "Email";
      })
      # HTML rendering
      (lib.mkIf config.services.xserver.enable w3m)
      (lib.mkIf config.services.xserver.enable dante)
    ];

    # Symlink these one at a time because aerc doesn't let you do bad things
    # like have globally readable files with plain text passwords
    home.configFile = {
      # FIXME Still doesn't have the right permissions
      # "aerc/accounts.conf".source = <config/aerc/accounts.conf>;
      "aerc/aerc.conf".source = "${configDir}/aerc/aerc.conf";
      "aerc/binds.conf".source = "${configDir}/aerc/binds.conf";
      "aerc/templates" = {
        source = "${configDir}/aerc/templates";
        recursive = true;
      };
    };
  };
}
