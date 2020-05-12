{ config, options, lib, pkgs, ... }:

with lib; {
  options.modules.shell.aerc = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.shell.aerc.enable {
    my = {
      packages = with pkgs; [
        aerc
        # HTML rendering
        (lib.mkIf config.services.xserver.enable w3m)
        (lib.mkIf config.services.xserver.enable dante)
      ];

      # Symlink these one at a time because aerc doesn't let you do bad things
      # like have globally readable files with plain text passwords
      home.xdg.configFile = {
        # FIXME Still doesn't have the right permissions
        # "aerc/accounts.conf".source = <config/aerc/accounts.conf>;
        "aerc/aerc.conf".source = <config/aerc/aerc.conf>;
        "aerc/binds.conf".source = <config/aerc/binds.conf>;
      };
    };
  };
}
