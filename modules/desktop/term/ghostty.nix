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

  # Tmux wrapper for auto-attach/create behavior
  tmuxWrapper = pkgs.writeShellScriptBin "ghostty-tmux-wrapper" ''
    #!/bin/sh
    # Auto-attach to existing tmux session or create new one
    set -e

    # Ensure tmux is available
    if ! command -v tmux >/dev/null 2>&1; then
      echo "Error: tmux not found in PATH" >&2
      exit 1
    fi

    # Session configuration
    SESSION="''${GHOSTTY_TMUX_SESSION:-main}"
    CWD="''${PWD:-.}"

    # Try to attach to existing session, else create new one
    if tmux has-session -t "$SESSION" 2>/dev/null; then
      exec tmux attach-session -t "$SESSION"
    else
      exec tmux new-session -s "$SESSION" -c "$CWD"
    fi
  '';
in
{
  options.modules.desktop.term.ghostty = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # On macOS, ghostty is installed via Homebrew cask
    # On Linux, use the Nix package
    user.packages = [ tmuxWrapper ] ++ optionals (!isDarwin) [ inputs.ghostty.packages.x86_64-linux.default ];

    # Symlink ghostty config directory
    home.configFile."ghostty" = {
      source = "${configDir}/ghostty";
      recursive = true;
    };

    # TODO: Add shell alias for copying terminfo
    # alias ghostcopy = "infocmp -x | ssh YOUR-SERVER -- tic -x -"
  };
}
