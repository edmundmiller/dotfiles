{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.dev.nixlang = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.dev.nixlang.enable {
    my.packages = with pkgs; [ nixfmt nixops ];
  };
}
