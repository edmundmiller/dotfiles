{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.agents.codex;
  inherit (config.dotfiles) configDir;

  # Dynamically concatenate all rule files from config/agents/rules/
  rulesDir = "${configDir}/agents/rules";
  ruleFiles = builtins.sort builtins.lessThan (
    builtins.filter (f: lib.hasSuffix ".md" f && f != "AGENTS.md") (builtins.attrNames (builtins.readDir rulesDir))
  );
  readRule = file: builtins.readFile "${rulesDir}/${file}";
  concatenatedRules = lib.concatMapStringsSep "\n\n" readRule ruleFiles;
in
{
  options.modules.agents.codex = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = [ pkgs.llm-agents.codex ];

    home.file = {
      # AGENTS.md built from shared agent rules (same source as Claude/OpenCode)
      ".codex/AGENTS.md".text = concatenatedRules;
    };

    home-manager.users.${config.user.name} =
      { lib, ... }:
      {
        home.activation.codex-config-bootstrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          codex_dir="$HOME/.codex"
          rules_dir="$codex_dir/rules"
          rules_template_dir="${configDir}/codex/rules"
          target="$codex_dir/config.toml"
          template="${configDir}/codex/config.toml"

          ${pkgs.coreutils}/bin/mkdir -p "$codex_dir"

          # Bootstrap sandbox allow-rules as local writable files so Codex can
          # amend them in place (e.g. execpolicy updates).
          ${pkgs.coreutils}/bin/mkdir -p "$rules_dir"
          for src in "$rules_template_dir"/*; do
            [ -e "$src" ] || continue

            name="$(${pkgs.coreutils}/bin/basename "$src")"
            dest="$rules_dir/$name"

            # Preserve any existing local edits; only replace old HM symlinks
            # and bootstrap files that are still missing.
            if [ -L "$dest" ]; then
              ${pkgs.coreutils}/bin/rm -f "$dest"
            fi

            if [ ! -e "$dest" ]; then
              ${pkgs.coreutils}/bin/cp "$src" "$dest"
            fi

            ${pkgs.coreutils}/bin/chmod u+w "$dest" 2>/dev/null || true
          done

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
