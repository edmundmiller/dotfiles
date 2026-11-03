{ pkgs, ... }:
{
  users.users = {
    # FIXME https://superuser.com/questions/1352477/nixos-nixops-declarative-group-management-and-services
    # Add KAH group 568
    emiller.extraGroups = [ "568" ];
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
