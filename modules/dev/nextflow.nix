{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.dev.nextflow;
in
{
  options.modules.dev.nextflow = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      jdk
      # my.nf-core
      my.gxf2bed
      my.snakefmt
    ];

    environment.shellAliases = {
      nf = "nextflow";
    };
  };
}
