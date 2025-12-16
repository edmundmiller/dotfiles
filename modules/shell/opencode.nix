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

    home.configFile = {
      # OpenCode uses XDG config directory: ~/.config/opencode/
      "opencode/opencode.jsonc".source = "${configDir}/opencode/opencode.jsonc";
      "opencode/AGENTS.md".source = "${configDir}/opencode/AGENTS.md";
      "opencode/agent".source = "${configDir}/opencode/agent";
      "opencode/command".source = "${configDir}/opencode/command";
      "opencode/tool".source = "${configDir}/opencode/tool";
      "opencode/plugin".source = "${configDir}/opencode/plugin";
      "opencode/ast-grep".source = "${configDir}/opencode/ast-grep";
    };
  };
}
