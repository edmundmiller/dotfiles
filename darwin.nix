# Darwin-specific base configuration
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
with lib;
{
  # Only apply these configs on Darwin systems
  config = mkIf (lib.hasSuffix "darwin" (pkgs.stdenv.hostPlatform.system or "x86_64-linux")) {
    # Import home-manager's darwin module
    imports = [ inputs.home-manager.darwinModules.home-manager ];

    # Darwin-specific nix configuration
    services.nix-daemon.enable = true;

    # Add darwin-rebuild to system packages
    environment.systemPackages = with pkgs; [
      inputs.nix-darwin.packages.${pkgs.stdenv.hostPlatform.system}.darwin-rebuild
      difftastic # Syntax-aware diff tool
    ];

    # Passwordless sudo for darwin-rebuild (enables agent-driven rebuilds)
    security.sudo.extraRules = [
      {
        users = [ config.user.name ];
        commands = [
          {
            command = "${
              inputs.nix-darwin.packages.${pkgs.stdenv.hostPlatform.system}.darwin-rebuild
            }/bin/darwin-rebuild";
            options = [ "NOPASSWD" ];
          }
          {
            command = "/run/current-system/sw/bin/darwin-rebuild";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    # Configure home-manager for Darwin
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      users.${config.user.name} = {
        home = {
          inherit (config.system) stateVersion;
        };
      };
    };
  };
}
