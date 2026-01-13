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
      # Skills and agents are shared with OpenCode - single source of truth
      ".claude/agents".source = "${configDir}/opencode/agent";
      ".claude/skills".source = "${configDir}/opencode/skill";
      ".claude/CLAUDE.md".source = "${configDir}/claude/CLAUDE.md";
      ".claude/settings.json".source = "${configDir}/claude/settings.json";

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
