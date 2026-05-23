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
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.amoxide = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # Installation guide installs both binaries.
    user.packages = [
      pkgs.my.amoxide
      pkgs.my.amoxide.tui
    ];

    home.configFile = {
      "amoxide/config.toml".source = "${configDir}/amoxide/config.toml";
      "amoxide/profiles.toml".source = "${configDir}/amoxide/profiles.toml";
      "amoxide/session.toml".source = "${configDir}/amoxide/session.toml";
    };

    modules.shell.zsh.rcInit = ''
      # amoxide shell integration
      # Equivalent to what `am setup zsh` wires in mutable dotfiles.
      if (( $+commands[am] )); then
        eval "$(am init -f zsh)"
      fi
    '';
  };
}
