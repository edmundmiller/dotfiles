{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.shell.kubernetes;
in {
  options.modules.shell.kubernetes = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [ kubectl kubernetes-helm ];

    # home.configFile = { };

    # modules.shell.zsh.rcFiles = [ "${configDir}/kubernetes/aliases.zsh" ];
  };
}
