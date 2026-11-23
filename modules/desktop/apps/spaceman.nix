{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
let
  cfg = config.modules.desktop.apps.spaceman;
in
{
  options.modules.desktop.apps.spaceman.enable = lib.my.mkBoolOpt false;

  config = lib.optionalAttrs isDarwin (
    lib.mkIf cfg.enable {
      # Home Manager's copyApps installs a real, signed bundle at this path.
      home-manager.users.${config.user.name}.home.packages = [ pkgs.my.spaceman ];
      # Do not enable the login-item reconciler on the work Mac: it deletes
      # unlisted login items. A one-shot open preserves existing startup apps.
      launchd.user.agents.spaceman.serviceConfig = {
        ProgramArguments = [
          "/usr/bin/open"
          "-g"
          "${config.user.home}/Applications/Home Manager Apps/Spaceman.app"
        ];
        RunAtLoad = true;
      };
      home.file."Library/Application Support/Spaceman/config.toml".source =
        "${config.dotfiles.configDir}/spaceman/config.toml";
    }
  );
}
