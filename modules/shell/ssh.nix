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
        
        # Global SSH configuration
        extraConfig = ''
          # Use 1Password SSH agent
          IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        '';

        # Host-specific configurations
        matchBlocks = {
          # NUC server
          "nuc" = {
            hostname = "192.168.1.222";
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
