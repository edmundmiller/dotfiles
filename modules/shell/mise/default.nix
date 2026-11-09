{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.mise;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.mise = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      mise
      nushell
    ];

    modules.shell.zsh = {
      rcInit = ''
        eval "$(mise activate zsh)"
        _cache mise completion zsh; compdef _mise mise
      '';
      rcFiles = [ "${configDir}/mise/aliases.zsh" ];
    };

    home.configFile = {
      "mise" = {
        source = "${configDir}/mise";
        recursive = true;
      };
    }
    # Shims load the cwd's mise.toml first, so an untrusted checkout breaks every
    # shimmed tool. Older mise rejects the setting as unknown.
    // optionalAttrs (versionAtLeast pkgs.mise.version "2026.11.2") {
      "mise/conf.d/settings.toml".text = ''
        [settings]
        activate_shims = false
      '';
    };
  };
}
