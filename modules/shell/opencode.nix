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
  cfg = config.modules.shell.opencode;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.shell.opencode = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      # Add opencode-related packages if any
    ];

    # Set NODE_PATH to help resolve @opencode-ai/plugin from symlinked tools
    home.sessionVariables = {
      NODE_PATH = "$HOME/.config/opencode/node_modules:${"\${NODE_PATH:-}"}";
    };

    # Install OpenCode tool dependencies after activation
    home.activation.opencodeInstallDeps = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ -f "$HOME/.config/opencode/package.json" ] && command -v bun >/dev/null 2>&1; then
        $DRY_RUN_CMD bun install --cwd "$HOME/.config/opencode" --silent 2>/dev/null || true
      fi
    '';

    home.configFile = {
      # OpenCode uses XDG config directory: ~/.config/opencode/
      "opencode/opencode.jsonc".source = "${configDir}/opencode/opencode.jsonc";
      "opencode/AGENTS.md".source = "${configDir}/opencode/AGENTS.md";
      "opencode/package.json".source = "${configDir}/opencode/package.json";
      "opencode/agent".source = "${configDir}/opencode/agent";
      "opencode/command".source = "${configDir}/opencode/command";
      "opencode/tool".source = "${configDir}/opencode/tool";
      "opencode/plugin".source = "${configDir}/opencode/plugin";
      "opencode/skills".source = "${configDir}/opencode/skills";
      "opencode/ast-grep".source = "${configDir}/opencode/ast-grep";
    };
  };
}
