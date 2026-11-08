{ pkgs, ... }:
{
  users.groups.users.gid = 100;

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

  users.users = {
    # FIXME https://superuser.com/questions/1352477/nixos-nixops-declarative-group-management-and-services
    # Add KAH group 568
    emiller.uid = 1000;
    emiller.extraGroups = [ "568" ];
    emiller.openssh.authorizedKeys.keys = (import ../../config/ssh/authorized-keys.nix).unasMachineKeys;
    monimiller = {
      uid = 1001;
      isNormalUser = true;
      createHome = true;
      shell = pkgs.zsh;
    };

    tdmiller = {
      uid = 1002;
      isNormalUser = true;
      createHome = true;
      shell = pkgs.bashInteractive;
    };
  };
}
