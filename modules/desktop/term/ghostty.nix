# modules/desktop/term/ghostty.nix
{
  config,
  inputs,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.term.ghostty;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.desktop.term.ghostty = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # On macOS, ghostty is installed via Homebrew cask
    # On Linux, use the Nix package
    user.packages = optionals (!isDarwin) [ inputs.ghostty.packages.x86_64-linux.default ];

    # Symlink ghostty config directory
    home.configFile."ghostty" = {
      source = "${configDir}/ghostty";
      recursive = true;
    };

    # TODO: Add shell alias for copying terminfo
    # alias ghostcopy = "infocmp -x | ssh YOUR-SERVER -- tic -x -"
  };
}
