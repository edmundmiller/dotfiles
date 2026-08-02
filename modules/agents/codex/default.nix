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
in
{
  options.modules.agents.codex = {
    enable = mkBoolOpt false;
    seqeraMcp.enable = mkBoolOpt false // {
      description = "Ensure Seqera MCP is registered in Codex's writable configuration.";
    };
  };

  config = mkIf cfg.enable {
    user.packages = [
      (lib.hiPrio pkgs.llm-agents.codex)
      codexVaultRestoreGuard
    ];

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

                    # Remove stale managed MCP blocks from the writable config.
                    ${pkgs.python3}/bin/python3 - "$target" ${
                      if cfg.seqeraMcp.enable then "1" else "0"
                    } <<'PY'
          import pathlib
          import re
          import sys

          path = pathlib.Path(sys.argv[1])
          seqera_mcp_enabled = sys.argv[2] == "1"
          content = path.read_text(encoding="utf-8") if path.exists() else ""
          original_content = content
          content = re.sub(
              r'(?ms)^\[\[hooks\.(?:PostToolUse|PreToolUse|Stop)\]\]\n\n'
              r'\[\[hooks\.(?:PostToolUse|PreToolUse|Stop)\.hooks\]\]\n'
              r'command = "/Users/emiller/\.git-ai/bin/git-ai checkpoint codex --hook-input stdin"\n'
              r'type = "command"\n\n?',
              "",
              content,
          )
          content = re.sub(
              r'(?ms)^\[hooks\.state\."/Users/emiller/\.codex/config\.toml:'
              r'(?:post_tool_use|pre_tool_use|stop):0:0"\]\n.*?(?=^\[|\Z)',
              "",
              content,
          )
          stale_mcp_servers = ["code" + "graph", "node_repl", "seqera"]
          next_content = content
          for server_name in stale_mcp_servers:
              pattern = re.compile(r'(?ms)^\[mcp_servers\.' + re.escape(server_name) + r'(?:\.[^\]]+)?\]\n.*?(?=^\[(?!mcp_servers\.' + re.escape(server_name) + r'(?:\.|\]))|\Z)')
              next_content = pattern.sub("", next_content)
          if seqera_mcp_enabled:
              features_pattern = re.compile(r'(?ms)^\[features\]\n.*?(?=^\[|\Z)')
              features_match = features_pattern.search(next_content)
              if features_match is None:
                  next_content = next_content.rstrip() + "\n\n[features]\nrmcp_client = true\n"
              else:
                  features = features_match.group()
                  if re.search(r'(?m)^rmcp_client\s*=', features):
                      features = re.sub(r'(?m)^rmcp_client\s*=.*$', "rmcp_client = true", features)
                  else:
                      features = features.rstrip() + "\nrmcp_client = true\n"
                  next_content = (
                      next_content[:features_match.start()]
                      + features
                      + next_content[features_match.end():]
                  )
              next_content = next_content.rstrip() + (
                  "\n\n[mcp_servers.seqera]\nurl = \"https://mcp.seqera.io/mcp\"\n"
              )
          next_content = next_content.rstrip() + "\n"
          if next_content != original_content:
              path.write_text(next_content, encoding="utf-8")
          PY
        '';

        home.activation.codex-vault-restore-guard-install =
          lib.hm.dag.entryAfter [ "codex-config-bootstrap" ]
            ''
              ${codexVaultRestoreGuard}/bin/codex-vault-restore-guard --install "$HOME/.codex/hooks.json"
            '';
      };
  };
}
