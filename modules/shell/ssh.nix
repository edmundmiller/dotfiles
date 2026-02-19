{
  config,
  lib,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.shell.ssh;
in
{
  options.modules.shell.ssh = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    # SSH client configuration
    home-manager.users.${config.user.name} = {
      programs.ssh = {
        enable = true;
        enableDefaultConfig = false;

        # Host-specific configurations
        matchBlocks = {
          # Default host config (required when using extraConfig)
          "*" = {
            # Use 1Password SSH agent
            extraOptions = {
              IdentityAgent = "\"~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock\"";
            };
          };

          # NUC server
          "nuc" = {
            hostname = "192.168.1.144";
            user = "emiller";
            forwardAgent = true;
          };

          # UNAS server (for future use)
          "unas" = {
            hostname = "192.168.1.150";
            user = "emiller";
            forwardAgent = true;
          };

          # GitHub
          "github.com" = {
            user = "git";
          };
        };
      };
    };
  };
}
