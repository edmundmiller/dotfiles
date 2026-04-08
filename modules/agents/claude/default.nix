{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents.claude;
  inherit (config.dotfiles) configDir;

  # Dynamically concatenate all rule files from config/agents/rules/
  rulesDir = "${configDir}/agents/rules";
  ruleFiles = builtins.sort builtins.lessThan (
    builtins.filter (f: lib.hasSuffix ".md" f && f != "AGENTS.md") (
      builtins.attrNames (builtins.readDir rulesDir)
    )
  );
  readRule = file: builtins.readFile "${rulesDir}/${file}";
  concatenatedRules = lib.concatMapStringsSep "\n\n" readRule ruleFiles;
in
{
  options.modules.agents.claude = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = [
      pkgs.llm-agents.claude-code
    ];

    home.file = {
      # Skills and agents are shared across all agents (Claude, OpenCode, Pi)
      # Single source of truth in config/agents/
      ".claude/agents".source = "${configDir}/agents/modes";
      # CLAUDE.md is built dynamically from config/agents/rules/*.md
      ".claude/CLAUDE.md".text = concatenatedRules;
      ".claude/settings.json".source = "${configDir}/claude/settings.json";

      # WakaTime configuration (reads agenix secret from current user's HOME)
      # NOTE: api_key_vault_cmd is argv-split by wakatime-cli (not shell-parsed),
      # so avoid sh -c with single quotes or it breaks with unmatched-quote errors.
      ".wakatime.cfg" = mkIf pkgs.stdenv.isDarwin {
        text = ''
          [settings]
          api_key_vault_cmd = cat ${config.user.home}/.local/share/agenix/wakatime-api-key
        '';
      };
    };

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.activation.claude-skills-bridge = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          mkdir -p "$HOME/.claude"
          rm -rf "$HOME/.claude/skills"
          ln -sfn "$HOME/.agents/skills" "$HOME/.claude/skills"
        '';
      };
  };
}
