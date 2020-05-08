# modules/dev/zsh.nix --- http://zsh.sourceforge.net/

{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.dev.zsh = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.dev.zsh.enable {
    my.packages = with pkgs; [ shellcheck shfmt my.zunit ];
  };
}
