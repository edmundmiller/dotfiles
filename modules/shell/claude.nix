{
  config,
  options,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.claude;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.claude = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      # Add claude-related packages if any
    ];

    home.file = {
      ".claude/settings.json".source = "${configDir}/claude/settings.json";
      # Note: settings.local.json, slash_commands, and commands are not tracked in git
      # and therefore not available in the nix store. Manage these locally if needed.
      ".claude/agents".source = "${configDir}/claude/agents";
      ".claude/config".source = "${configDir}/claude/config";

      # WakaTime configuration (references agenix-decrypted secret)
      ".wakatime.cfg" = mkIf pkgs.stdenv.isDarwin {
        text = ''
          [settings]
          api_key_vault_cmd = cat ${config.home-manager.users.${config.user.name}.age.secretsDir}/wakatime-api-key
        '';
      };
    };

    # Source Claude aliases in zsh
    modules.shell.zsh.rcFiles = [ "${configDir}/claude/aliases.zsh" ];
  };
}