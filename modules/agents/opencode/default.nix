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
        opencodeV1ConfigDir = "${config.home.homeDirectory}/.config/opencode";
        opencodeV2ConfigDir = "${config.home.homeDirectory}/.config/opencode2/opencode";
      in
      {
        # V2 gets an isolated XDG root so incompatible V1 plugins are never loaded.
        xdg.configFile = {
          "opencode2/opencode/opencode.jsonc".source = "${configDir}/opencode/opencode.jsonc";
          "opencode2/opencode/AGENTS.md".source = "${configDir}/agents/core.md";

          # TODO(opencode-v2): Restore DCP after its plugin supports the V2 API.
          # TODO(opencode-v2): Restore smart-title after its plugin supports the V2 API.

          "opencode2/opencode/agent" = {
            source = "${configDir}/agents/modes";
            recursive = true;
          };
          "opencode2/opencode/command" = {
            source = "${configDir}/opencode/command";
            recursive = true;
          };
        };

        home.activation.opencode-v1-cleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ -d "${opencodeV1ConfigDir}" ] && [ ! -L "${opencodeV1ConfigDir}" ]; then
            ${pkgs.coreutils}/bin/chmod -R u+w "${opencodeV1ConfigDir}"
          fi
          ${pkgs.coreutils}/bin/rm -rf "${opencodeV1ConfigDir}"
          ${pkgs.coreutils}/bin/mkdir -p "${opencodeV2ConfigDir}"
          ${pkgs.coreutils}/bin/ln -sfn "${opencodeV2ConfigDir}" "${opencodeV1ConfigDir}"
        '';
      };
  };
}
