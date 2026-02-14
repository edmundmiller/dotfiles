{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.editors.vim;
in
{
  options.modules.editors.vim = {
    enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      neovim
      editorconfig-core-c
      # ctags provided by emacs package
      unstable.lua-language-server
      lazygit
    ];

    environment.shellAliases = {
      vim = "nvim";
      v = "nvim";
      nvim-hierarchical = ''NVIM_APPNAME="nvim-kickstart" nvim'';
    };

    # Symlink kickstart config to ~/.config/nvim-kickstart
    home.file.".config/nvim-kickstart".source = ../../config/nvim-kickstart;

    # Set nvim as the default editor
    env = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
