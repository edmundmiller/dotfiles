{ pkgs, ... }:
{
  user.packages = [
    pkgs.my.bend
    pkgs.my.callstack-diff
    pkgs.my.fx
    pkgs.my.sgrep
  ];
}
