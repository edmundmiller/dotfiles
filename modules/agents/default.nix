{ pkgs, ... }:
{
  user.packages = [
    pkgs.my.callstack-diff
    pkgs.my.fx
  ];
}
