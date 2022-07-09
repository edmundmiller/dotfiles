{ pkgs, ... }: {
  users.users = {
    monimiller = {
      isNormalUser = true;
      createHome = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIjADG7vmI/moup3J2UyFjj51CNpV4VVo+f9oOr/n4r4 monicadd4@gmail.com"
      ];
      shell = pkgs.bashInteractive;
    };

    tdmiller = {
      isNormalUser = true;
      createHome = true;
      shell = pkgs.bashInteractive;
      openssh.authorizedKeys.keyFiles = [ "/home/tdmiller/.ssh/id_tailscale.pub" ];
    };
  };
}
