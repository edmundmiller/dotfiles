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
          # No gateway config here — Mac is a node only.
          # Node→gateway pairing is runtime state (done in app UI).
        };
      };
    };
  };
}
