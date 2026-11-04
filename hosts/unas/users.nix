{ pkgs, ... }:
{
  users.users = {
    # FIXME https://superuser.com/questions/1352477/nixos-nixops-declarative-group-management-and-services
    # Add KAH group 568
    emiller.extraGroups = [ "568" ];
    # NUC's existing user identity, limited to its LAN and Tailscale addresses.
    emiller.openssh.authorizedKeys.keys = [
      ''from="192.168.1.222,100.112.179.64",no-agent-forwarding,no-port-forwarding,no-X11-forwarding ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB6NdOGUlSTcYb9lB7CGx98mAZwvgATLNoRpB69CwE/F nuc-emiller''
    ];
    monimiller = {
      isNormalUser = true;
      createHome = true;
      shell = pkgs.zsh;
    };

    tdmiller = {
      isNormalUser = true;
      createHome = true;
      shell = pkgs.bashInteractive;
    };
  };

  # deploy-rs uses emiller with interactiveSudo=false, as on the NUC.
  security.sudo.extraRules = [
    {
      users = [ "emiller" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
