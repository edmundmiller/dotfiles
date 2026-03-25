{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:

with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.openclaw;
  user = config.user.name;
  remoteSshTarget = "nuc";
in
{
  options.modules.desktop.apps.openclaw = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # Install OpenClaw.app via Homebrew cask
    homebrew.casks = [ "openclaw" ];

    # Keep app-local macOS prefs aligned with the Nix-managed OpenClaw config.
    system.defaults.CustomUserPreferences."ai.openclaw.mac" = {
      openclaw.remoteTarget = remoteSshTarget;
    };

    home-manager.users.${user} = _: {
      home.packages = [
        inputs.google-workspace-cli.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];

      # Force-overwrite openclaw.json so Home Manager can replace a
      # mutable config file if OpenClaw.app has written local changes.
      home.file.".openclaw/openclaw.json".force = true;

      programs.openclaw = {
        enable = true;
        # App installed via Homebrew — don't install via Nix
        installApp = false;

        instances.default = {
          enable = true;
          # No local gateway in remote mode — OpenClaw.app handles the connection
          launchd.enable = false;
          appDefaults = {
            enable = true;
            nixMode = true;
            # Attach to remote gateway, don't spawn local
            attachExistingOnly = true;
          };
          # Official Remote over SSH path: rely on SSH + device pairing
          # instead of a shared gateway token.
          config.agents.defaults.thinkingDefault = "high";
          config.gateway = {
            mode = "remote";
            remote = {
              transport = "ssh";
              sshTarget = remoteSshTarget;
            };
          };
        };
      };

    };
  };
}
