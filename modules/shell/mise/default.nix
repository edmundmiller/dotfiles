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
  inherit (config.dotfiles) binDir configDir;
in
{
  options.modules.shell.mise = {
    enable = mkBoolOpt false;
  };

  # Runs whenever Claude is enabled, so disabling mise also removes our hooks.
  config = mkMerge [
    (mkIf cfg.enable {
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
      };
    })

    {
      home-manager.users.${config.user.name} =
        { lib, ... }:
        {
          home.activation.mise-claude-hooks = mkIf config.modules.agents.claude.enable (
            lib.hm.dag.entryAfter [ "writeBoundary" "claude-settings-bootstrap" ] ''
              ${pkgs.python3}/bin/python3 ${./claude-hooks.py} "$HOME/.claude/settings.json" ${
                if cfg.enable then ''"${binDir}/mise-trust-worktree --hook"'' else ""
              }
            ''
          );
        };
    }
  ];
}
