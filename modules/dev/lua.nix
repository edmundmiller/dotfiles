# modules/dev/lua.nix --- https://www.lua.org/

{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.dev.lua = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.dev.lua.enable {
    my = {
      packages = with pkgs; [ lua luaPackages.moonscript luarocks ];

      zsh.rc = ''eval "$(luarocks path --bin)"'';
    };
  };
}
