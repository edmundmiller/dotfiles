# modules/dev/zsh.nix --- http://zsh.sourceforge.net/

{ pkgs, ... }: {
  my.packages = with pkgs; [ shellcheck my.zunit ];
}
