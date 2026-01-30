{
  lib,
  pkgs,
  ...
}:
with lib;
let
  system = pkgs.stdenv.hostPlatform.system or "x86_64-linux";
  isDarwin = hasSuffix "darwin" system;
  isLinux = hasSuffix "linux" system;
  isNixOS = isLinux; # For clarity when we specifically mean NixOS
in
{
  inherit
    isDarwin
    isLinux
    isNixOS
    system
    ;

  # Helper to get the correct home base directory
  homeBase = if isDarwin then "/Users" else "/home";
}
