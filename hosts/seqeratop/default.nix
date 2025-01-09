{
  imports = [
    ../home.nix
    ./disko.nix
    ./hardware-configuration.nix
  ];

  modules = {
    editors = {
      default = "nvim";
      emacs.enable = true;
      vim.enable = true;
    };
    dev = {
      python.enable = true;
      python.conda.enable = true;
      R.enable = true;
      rust.enable = true;
    };

    shell = {
      "1password".enable = true;
      ai.enable = true;
      direnv.enable = true;
      git.enable = true;
      tmux.enable = true;
      zsh.enable = true;
    };

    services = {
      docker.enable = true;
      ssh.enable = true;
    };
  };
}
