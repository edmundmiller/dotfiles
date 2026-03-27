{
  config,
  lib,
  pkgs,
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
    user.packages = [ pkgs.llm-agents.codex ];

    home.file = {
      # AGENTS.md built from shared agent rules (same source as Claude/OpenCode)
      ".codex/AGENTS.md".text = concatenatedRules;

      # Sandbox allow-rules
      ".codex/rules" = {
        source = "${configDir}/codex/rules";
        recursive = true;
      };
    };

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.activation.codex-config-bootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          codex_dir="$HOME/.codex"
          target="$codex_dir/config.toml"
          template="${configDir}/codex/config.toml"

          ${pkgs.coreutils}/bin/mkdir -p "$codex_dir"

          # Codex mutates config.toml (plugins, approvals, model switching).
          # Keep a writable local file and only bootstrap from template when needed.
          if [ -L "$target" ]; then
            tmp="$(${pkgs.coreutils}/bin/mktemp)"
            ${pkgs.coreutils}/bin/cp "$target" "$tmp" 2>/dev/null || ${pkgs.coreutils}/bin/cp "$template" "$tmp"
            ${pkgs.coreutils}/bin/rm -f "$target"
            ${pkgs.coreutils}/bin/mv "$tmp" "$target"
          elif [ ! -e "$target" ]; then
            ${pkgs.coreutils}/bin/cp "$template" "$target"
          fi

          ${pkgs.coreutils}/bin/chmod u+w "$target" 2>/dev/null || true
        '';
      };
  };
}
