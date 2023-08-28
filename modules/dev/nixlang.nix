{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.dev.nixlang;
in {
  options.modules.dev.nixlang = {enable = mkBoolOpt false;};

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      alejandra
      nil
      # nixops
    ];

    environment.shellAliases = {
      devenv-init = "nix flake init --template github:cachix/devenv && ${pkgs.direnv}/bin/direnv allow";
    };
  };
}
