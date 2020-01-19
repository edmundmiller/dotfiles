{ config, lib, pkgs, ... }:

{
  my = {
    packages = with pkgs; [ editorconfig-core-c neovim ];

    env.EDITOR = "nvim";
    env.VIMINIT =
      "let \\$MYVIMRC='\\$XDG_CONFIG_HOME/nvim/init.vim' | source \\$MYVIMRC";

    alias.v = "nvim";

    my.home.xdg = {
      configFile."nvim" = {
        source = <config/nvim>;
        recursive = true;
      };
    };
  };
}
