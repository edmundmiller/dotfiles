{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.amoxide;
in
{
  options.modules.shell.amoxide = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # Installation guide installs both binaries.
    user.packages = with pkgs.my; [
      amoxide
      amoxide-tui
    ];

    modules.shell.zsh.rcInit = ''
      # amoxide shell integration
      # Equivalent to what `am setup zsh` wires in mutable dotfiles.
      if (( $+commands[am] )); then
        eval "$(am init -f zsh)"
      fi
    '';
  };
}
