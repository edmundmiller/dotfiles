{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.dev.java = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.dev.java.enable {
    my.packages = with pkgs; [
        jdk
    ];
  };
}
