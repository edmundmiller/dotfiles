{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.claude;
  inherit (config.dotfiles) configDir;

  # Dynamically concatenate all rule files from config/agents/rules/
  rulesDir = "${configDir}/agents/rules";
  ruleFiles = builtins.sort builtins.lessThan (
    builtins.filter (f: lib.hasSuffix ".md" f) (builtins.attrNames (builtins.readDir rulesDir))
  );
  readRule = file: builtins.readFile "${rulesDir}/${file}";
  concatenatedRules = lib.concatMapStringsSep "\n\n" readRule ruleFiles;
in
{
  options.modules.shell.claude = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home.file = {
      # Skills and agents are shared across all agents (Claude, OpenCode, Pi)
      # Single source of truth in config/agents/
      ".claude/agents".source = "${configDir}/agents/modes";
      ".claude/skills".source = "${configDir}/agents/skills";
      # CLAUDE.md is built dynamically from config/agents/rules/*.md
      ".claude/CLAUDE.md".text = concatenatedRules;
      ".claude/settings.json".source = "${configDir}/claude/settings.json";

      # WakaTime configuration (references agenix-decrypted secret)
      ".wakatime.cfg" = mkIf pkgs.stdenv.isDarwin {
        text = ''
          [settings]
          api_key_vault_cmd = cat ${
            config.home-manager.users.${config.user.name}.age.secretsDir
          }/wakatime-api-key
        '';
      };
    };
  };
}
