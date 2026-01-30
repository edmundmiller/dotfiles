{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.docker;
in
{
  options.modules.services.docker = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      user.packages = with pkgs; [
        docker
        unstable.docker-compose
      ];

      env.DOCKER_CONFIG = "$XDG_CONFIG_HOME/docker";
      env.MACHINE_STORAGE_PATH = "$XDG_DATA_HOME/docker/machine";

      modules.shell.zsh.rcFiles = [ "${configDir}/docker/aliases.zsh" ];
    }

    # NixOS-only Docker daemon and group configuration
    (optionalAttrs (!isDarwin) {
      user.extraGroups = [ "docker" ];

      virtualisation = {
        docker = {
          enable = true;
          autoPrune.enable = true;
          enableOnBoot = false;
          storageDriver = "zfs";
          # listenOptions = [];
        };
      };
    })
  ]);
}
