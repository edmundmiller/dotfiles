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

    # ghostty terminfo isn't supported over ssh, so revert to a known one
    modules.shell.zsh.rcInit = ''
      [ "$TERM" = ghostty ] && [ -n "$SSH_CONNECTION" ] && export TERM=xterm-256color
    '';

    # Symlink ghostty config directory
    home.configFile."ghostty" = {
      source = "${configDir}/ghostty";
      recursive = true;
    };
  };
}
