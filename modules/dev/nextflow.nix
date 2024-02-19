{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.dev.nextflow;
in {
  options.modules.dev.nextflow = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      jdk17
      # my.nf-core
      my.gxf2bed
    ];

    environment.shellAliases = {
      nf = "nextflow";
    };
  };
}
