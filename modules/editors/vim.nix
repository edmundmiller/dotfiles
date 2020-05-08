{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.editors.vim = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf config.modules.editors.vim.enable {
    my = {
      packages = with pkgs; [ editorconfig-core-c neovim ];

      env.VIMINIT =
        "let \\$MYVIMRC='\\$XDG_CONFIG_HOME/nvim/init.vim' | source \\$MYVIMRC";
      alias.vim = "nvim";
      alias.v = "nvim";
    };
  };
}
