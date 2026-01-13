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
    home.file = {
      # Note: settings.json is NOT symlinked because Claude Code needs write access for plugin management.
      # Copy manually: cp ~/.config/dotfiles/config/claude/settings.json ~/.claude/settings.json
      ".claude/agents".source = "${configDir}/claude/agents";
      ".claude/skills".source = "${configDir}/claude/skills";
      ".claude/CLAUDE.md".source = "${configDir}/claude/CLAUDE.md";

      # WakaTime configuration (references agenix-decrypted secret)
      ".wakatime.cfg" = mkIf pkgs.stdenv.isDarwin {
        text = ''
          [settings]
          api_key_vault_cmd = cat ${config.home-manager.users.${config.user.name}.age.secretsDir}/wakatime-api-key
        '';
      };
    };
  };
}