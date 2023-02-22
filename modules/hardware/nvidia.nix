{ options, config, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.hardware.nvidia;

  nvStable = config.boot.kernelPackages.nvidiaPackages.stable;
  nvBeta = config.boot.kernelPackages.nvidiaPackages.beta;
  nvidiaPkg =
    if (lib.versionOlder nvBeta.version nvStable.version)
    then config.boot.kernelPackages.nvidiaPackages.stable
    else config.boot.kernelPackages.nvidiaPackages.beta;
in {
  options.modules.hardware.nvidia = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    hardware.opengl.enable = true;

    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.nvidia.package = nvidiaPkg;

    environment.systemPackages = with pkgs;
      [
        # Respect XDG conventions, damn it!
        (writeScriptBin "nvidia-settings" ''
          #!${stdenv.shell}
          mkdir -p "$XDG_CONFIG_HOME/nvidia"
          exec ${config.boot.kernelPackages.nvidia_x11.settings}/bin/nvidia-settings --config="$XDG_CONFIG_HOME/nvidia/settings"
        '')
      ];
  };
}