{pkgs, ...}: {
  users.users = {
    # FIXME https://superuser.com/questions/1352477/nixos-nixops-declarative-group-management-and-services
    # Add KAH group 568
    emiller.extraGroups = ["568"];
    monimiller = {
      isNormalUser = true;
      createHome = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjADG7vmI/moup3J2UyFjj51CNpV4VVo+f9oOr/n4r4 monicadd4@gmail.com"
      ];
      shell = pkgs.zsh;
    };

    tdmiller = {
      isNormalUser = true;
      createHome = true;
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keyFiles = ["/home/tdmiller/.ssh/id_tailscale.pub"];
    };
  };
}
