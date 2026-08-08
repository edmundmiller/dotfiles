{ pkgs, ... }:
{
  user.packages = [ pkgs.my.callstack-diff ];
}
