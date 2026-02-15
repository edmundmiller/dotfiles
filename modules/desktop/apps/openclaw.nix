{
  config,
  lib,
  ...
}:

with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.openclaw;
  user = config.user.name;
in
{
  options.modules.desktop.apps.openclaw = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # Install OpenClaw.app via Homebrew cask
    homebrew.casks = [ "openclaw" ];

    home-manager.users.${user} = {
      programs.openclaw = {
        enable = true;
        # App installed via Homebrew — don't install via Nix
        installApp = false;
        documents = ../../../config/openclaw/documents;

        instances.default = {
          enable = true;
          # App needs launchd to run
          launchd.enable = true;
          appDefaults = {
            enable = true;
            nixMode = true;
            # Attach to remote gateway, don't spawn local
            attachExistingOnly = true;
          };
          # GP2: connect to NUC gateway via Tailscale Serve (wss://)
          config.gateway = {
            mode = "remote";
            remote = {
              url = "wss://nuc.cinnamon-rooster.ts.net";
              transport = "direct";
              token = "2395843a6c856b1380154e960875c5b6cbcf238c4d26b2ef14eb2dada188f6fb";
            };
          };
        };
      };
    };
  };
}
