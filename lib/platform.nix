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

  mkUnsupportedPlatformConfig =
    {
      enabled,
      moduleName,
      supportedPlatform,
      unsupported,
      config,
    }:
    mkMerge (
      [
        {
          assertions = [
            {
              assertion = !(enabled && unsupported);
              message = "${moduleName} is only supported on ${supportedPlatform}.";
            }
          ];
        }
      ]
      ++ optional (!unsupported) (mkIf enabled config)
    );

  mkNixOSOnlyConfig =
    isDarwin: moduleName: enabled: config:
    mkUnsupportedPlatformConfig {
      inherit enabled moduleName config;
      supportedPlatform = "NixOS";
      unsupported = isDarwin;
    };

  mkDarwinOnlyConfig =
    isDarwin: moduleName: enabled: config:
    mkUnsupportedPlatformConfig {
      inherit enabled moduleName config;
      supportedPlatform = "Darwin";
      unsupported = !isDarwin;
    };
in
{
  inherit
    isDarwin
    isLinux
    isNixOS
    system
    mkNixOSOnlyConfig
    mkDarwinOnlyConfig
    ;

  # Helper to get the correct home base directory
  homeBase = if isDarwin then "/Users" else "/home";
}
