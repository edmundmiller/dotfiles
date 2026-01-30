{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.dev.nixlang;
in
{
  options.modules.dev.nixlang = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      nixfmt-rfc-style
      unstable.manix
      unstable.nixd
      nix-update
      nixpkgs-review
      nix-search-cli
      nix-index
    ];

    environment.shellAliases = {
      devenv-init = "nix flake init --template github:cachix/devenv && ${pkgs.direnv}/bin/direnv allow";
      devenv-parts = "nix flake init --template github:cachix/devenv#flake-parts && ${pkgs.direnv}/bin/direnv allow";
      manfzf = "manix \"\" | grep '^# ' | sed 's/^# \(.*\) (.*/\1/;s/ (.*//;s/^# //' | fzf --preview=\"manix '{}'\" | xargs manix";
    };
  };
}
