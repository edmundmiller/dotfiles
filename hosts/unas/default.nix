# No u nas

{ ... }: {
  imports = [ ../home.nix ./hardware-configuration.nix ./nas.nix ];

  modules = {
    editors = {
      default = "nvim";
      vim.enable = true;
    };
    shell = {
      git.enable = true;
      zsh.enable = true;
    };
    services = {
      docker.enable = true;
      jellyfin.enable = true;
      ssh.enable = true;
      syncthing.enable = true;
    };
  };

  time.timeZone = "America/Chicago";

  users.users.moni = {
      isNormalUser = true;
  };
}
