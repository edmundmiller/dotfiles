{
  config,
  lib,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.rex;
  themeFile =
    {
      catppuccin = ../../config/rex/themes-catppuccin.json;
      seqera = ../../config/rex/themes-seqera.json;
    }
    .${config.modules.desktop.term.themeStack.variant};
  themeIDs = listToAttrs (
    map (theme: nameValuePair theme.appearance theme.id) (
      builtins.fromJSON (builtins.readFile themeFile)
    )
  );
in
{
  options.modules.shell.rex.enable = mkBoolOpt false;

  config = mkIf cfg.enable (
    {
      # The Rex app (currently macOS-only) is installed separately. Nix owns only its config.
      # The Linux Rex server is configured separately through services.rex.
      home.configFile."rex/init.lua".source = "${config.dotfiles.configDir}/rex/init.lua";
      modules.agents.mcp.servers.superlogical.enable = mkDefault true;
    }
    // optionalAttrs isDarwin {
      system.defaults.CustomUserPreferences."com.superlogical.rex" = {
        "Workspace.tabStyle" = "vertical";
        "Workspace.lightThemeID" = themeIDs.light;
        "Workspace.darkThemeID" = themeIDs.dark;
      };

      home-manager.users.${config.user.name} =
        { lib, ... }:
        {
          # Rex stores imported themes as JSON inside NSData, not a plist array.
          home.activation.rexThemes = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            run /usr/bin/defaults write com.superlogical.rex Workspace.customThemes -data \
              "$(/usr/bin/xxd -p ${themeFile} | /usr/bin/tr -d '\n')"
          '';
        };
    }
  );
}
