{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.codex;
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
  options.modules.shell.codex = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    home.file = {
      ".codex/config.toml".source = "${configDir}/codex/config.toml";

      # AGENTS.md built from shared agent rules (same source as Claude/OpenCode)
      ".codex/AGENTS.md".text = concatenatedRules;

      # Sandbox allow-rules
      ".codex/rules" = {
        source = "${configDir}/codex/rules";
        recursive = true;
      };
    };
  };
}
