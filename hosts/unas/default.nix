# No u nas

{ ... }: {
  imports = [ ../home.nix ./hardware-configuration.nix ];

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
      k3s.enable = true;
      ssh.enable = true;
      syncthing.enable = true;
    };
  };

  time.timeZone = "America/Chicago";
}
