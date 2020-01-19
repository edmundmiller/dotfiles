{ config, lib, pkgs, ... }:

{
  my = {
    packages = with pkgs; [ editorconfig-core-c neovim ];

    env.EDITOR = "nvim";
    env.VIMINIT =
      "let \\$MYVIMRC='\\$XDG_CONFIG_HOME/nvim/init.vim' | source \\$MYVIMRC";

    alias.v = "nvim";

    # TODO Import my config
  };
}
