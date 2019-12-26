{ config, lib, pkgs, ... }:

{
  environment = {
    sessionVariables = {
      EDITOR = "nvim";
      VIMINIT =
        "let \\$MYVIMRC='\\$XDG_CONFIG_HOME/nvim/init.vim' | source \\$MYVIMRC";
    };
    systemPackages = with pkgs; [ editorconfig-core-c neovim ];
  };

  home-manager.users.emiller = {
    xdg.configFile = {
      "zsh/rc.d/aliases.nvim.zsh".source = <config/nvim/aliases.zsh>;
      "zsh/rc.d/env.nvim.zsh".source = <config/nvim/env.zsh>;
      "nvim" = {
        source = <config/nvim>;
        recursive = true;
      };
    };
  };
}
