{ pkgs, lib, config, ... }:

lib.mkMerge [
  (
    (import ./common.nix) {
      config = config;
      pkgs = pkgs;
    }
  )
  # (
  #   lib.mkIf
  #   (builtins.pathExists "${config.home.homeDirectory}/private_secrets")
  #   (
  #     (import ./private.nix) {
  #       config = config;
  #       pkgs = pkgs;
  #     }
  #   )
  # )
]
