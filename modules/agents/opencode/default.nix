{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkIf;
  inherit (lib.my) mkBoolOpt;
  cfg = config.modules.agents.opencode;
  ghosttyCfg = config.modules.desktop.term.ghostty;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.agents.opencode = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # When Ghostty is enabled, add OpenCode-specific keybindings
    modules.desktop.term.ghostty.keybindingFiles = mkIf ghosttyCfg.enable [
      "${configDir}/ghostty/opencode-keybindings.conf"
    ];
    user.packages = [
      pkgs.llm-agents.opencode
    ];

    home-manager.users.${config.user.name} =
      { config, lib, ... }:
      let
        opencodeConfigDir = "${config.home.homeDirectory}/.config/opencode";
      in
      {
        xdg.configFile = {
          "opencode/AGENTS.md".source = "${configDir}/agents/core.md";

          # TODO(opencode-v2): Restore DCP after its plugin supports the V2 API.
          # TODO(opencode-v2): Restore smart-title after its plugin supports the V2 API.

          "opencode/agent" = {
            source = "${configDir}/agents/modes";
            recursive = true;
          };
          "opencode/command" = {
            source = "${configDir}/opencode/command";
            recursive = true;
          };
        };

        home.activation.opencode-config-bootstrap = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          target="${opencodeConfigDir}/opencode.jsonc"
          if [ ! -e "$target" ]; then
            ${pkgs.coreutils}/bin/install -D -m 0600 ${configDir}/opencode/opencode.jsonc "$target"
          fi
        '';
      };
  };
}
