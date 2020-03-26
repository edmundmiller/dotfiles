# modules/chat.nix

{ pkgs, ... }: {
  my.packages = with pkgs; [ discord my.ripcord unstable.teams ];
}
