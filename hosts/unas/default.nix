# No u nas

{ ... }: {
  imports = [ ../personal.nix ./hardware-configuration.nix ];

  modules = {
    editors = {
      default = "nvim";
      vim.enable = true;
    };
    shell = {
      git.enable = true;
      zsh.enable = true;
    };
    services.ssh.enable = true;
  };

  time.timeZone = "America/Chicago";
}
