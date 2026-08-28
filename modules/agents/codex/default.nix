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
    builtins.filter (f: lib.hasSuffix ".md" f && f != "AGENTS.md") (
      builtins.attrNames (builtins.readDir rulesDir)
    )
  );
  readRule = file: builtins.readFile "${rulesDir}/${file}";
  concatenatedRules = lib.concatMapStringsSep "\n\n" readRule ruleFiles;
  codexVaultRestoreGuard = pkgs.writeTextFile {
    name = "codex-vault-restore-guard";
    destination = "/bin/codex-vault-restore-guard";
    executable = true;
    text = "#!${pkgs.python3}/bin/python3\n${builtins.readFile "${configDir}/codex/hooks/vault_restore_guard.py"}";
  };
  codexMcpReconciler = pkgs.writeText "codex-mcp-reconciler.py" (
    builtins.readFile "${configDir}/codex/reconcile_mcp.py"
  );
  codexHomeAssistantLauncher = pkgs.writeShellScriptBin "codex-ha" ''
    CODEX_HOME_ASSISTANT_SECRET_REFERENCE=${escapeShellArg cfg.homeAssistantMcp.secretReference}
    OP_BIN=${escapeShellArg (lib.getExe pkgs._1password-cli)}
    CODEX_BIN=${escapeShellArg (lib.getExe pkgs.llm-agents.codex)}
    ${builtins.readFile "${configDir}/codex/codex-ha.sh"}
  '';
in
{
  options.modules.agents.codex = {
    enable = mkBoolOpt false;
    homeAssistantMcp.enable = mkBoolOpt false // {
      description = "Ensure Home Assistant MCP is registered in Codex's writable configuration.";
    };
    homeAssistantMcp.secretReference = mkOption {
      type = types.str;
      default = "";
      description = "1Password reference exposed to token-backed Codex sessions by codex-ha.";
    };
    seqeraMcp.enable = mkBoolOpt false // {
      description = "Ensure Seqera MCP is registered in Codex's writable configuration.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.homeAssistantMcp.enable || cfg.homeAssistantMcp.secretReference != "";
        message = "modules.agents.codex.homeAssistantMcp.secretReference is required when Home Assistant MCP is enabled";
      }
    ];

    user.packages = [
      (lib.hiPrio pkgs.llm-agents.codex)
      codexVaultRestoreGuard
    ]
    ++ optionals cfg.homeAssistantMcp.enable [ codexHomeAssistantLauncher ];

    home.file = {
      # AGENTS.md built from shared agent rules (same source as Claude/OpenCode)
      ".codex/AGENTS.md".text = concatenatedRules;
      ".codex/agents/luna_worker.toml".source = "${configDir}/codex/agents/luna_worker.toml";
      ".codex/agents/terra_worker.toml".source = "${configDir}/codex/agents/terra_worker.toml";
      ".codex/agents/sol_reviewer.toml".source = "${configDir}/codex/agents/sol_reviewer.toml";
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

          # Reconcile only the host-scoped MCP integrations. This source can
          # also be run directly for a Codex-config-only recovery.
          ${pkgs.python3}/bin/python3 ${codexMcpReconciler} --legacy-cleanup "$target" ${
            if cfg.seqeraMcp.enable then "1" else "0"
          } ${if cfg.homeAssistantMcp.enable then "1" else "0"}
        '';

        home.activation.codex-vault-restore-guard-install =
          lib.hm.dag.entryAfter [ "codex-config-bootstrap" ]
            ''
              ${codexVaultRestoreGuard}/bin/codex-vault-restore-guard --install "$HOME/.codex/hooks.json"
            '';
      };
  };
}
