{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.wt;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.wt = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # Note: worktrunk (wt) is installed via homebrew
    # The formula is not yet available in nixpkgs
    # Homebrew tap: max-sixty/worktrunk
    # Formula: wt

    # Link worktrunk user config template
    home.configFile = {
      "worktrunk/config.toml".source = "${configDir}/wt/config.toml";
    };

    # Source shell integration (for directory changing) and aliases
    modules.shell.zsh.envFiles = [ "${configDir}/wt/env.zsh" ];
    modules.shell.zsh.rcFiles = [ "${configDir}/wt/aliases.zsh" ];
  };
}
