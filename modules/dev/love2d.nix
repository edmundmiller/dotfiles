# modules/dev/love2d.nix --- https://love2d.org/

{ pkgs, ... }: {
  my.packages = with pkgs; [ love lua luaPackages.moonscript luarocks ];
}
