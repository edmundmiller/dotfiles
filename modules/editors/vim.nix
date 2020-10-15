{ config, options, lib, pkgs, ... }:

with lib;
with lib.my;
let cfg = config.modules.editors.vim;
in {
  options.modules.editors.vim = { enable = mkBoolOpt false; };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [ editorconfig-core-c neovim ];

    # env.VIMINIT = "let \\$MYVIMRC='\\$XDG_CONFIG_HOME/nvim/init.vim' | source \\$MYVIMRC";

    environment.shellAliases = {
      vim = "nvim";
      v = "nvim";
    };
  };
}
