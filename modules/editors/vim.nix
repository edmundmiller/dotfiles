{
  config,
  options,
  lib,
  pkgs,
  inputs,
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
  imports = [ inputs.nixvim.nixosModules.nixvim ];

  config = mkIf cfg.enable {
    user.packages = with pkgs; [
      editorconfig-core-c
      # inputs.neovim-nightly-overlay.packages.${pkgs.system}.default
      ctags
      unstable.lua-language-server
      lazygit
    ];

    programs.nixvim = {
      enable = true;
      # vimdiffAlias = true;
      clipboard.register = "unnamedplus";
      vimAlias = true;
      editorconfig.enable = true;
      globals.mapleader = "SPC";
      plugins = {
        copilot-chat.enable = true;
        copilot-lua.enable = true;
        dressing.enable = true;
        harpoon.enable = true;
        harpoon.enableTelescope = true;
        neoscroll.enable = true;
        neotest.enable = true;
        telescope.enable = true;
        surround.enable = true;
        todo-comments.enable = true;
      };
      extraPlugins = with pkgs; [
        (vimUtils.buildVimPlugin {
          name = "nextflow-vim";
          src = pkgs.fetchFromGitHub {
            owner = "Mxrcon";
            repo = "nextflow-vim";
            rev = "77a349ad259f536c03fe2888ed9137249fa7d40e";
            hash = "sha256-+w2LFWfeuur1t5kNvA3SAyF9mxPfEL7SW/vXXXsVnSc=";
          };
        })

        # avante
        (vimUtils.buildVimPlugin {
          name = "avante-vim";
          src = pkgs.fetchFromGitHub {
            owner = "yetone";
            repo = "avante.nvim";
            rev = "b87404588545c26b297f776919255ad0a53eafe0";
            hash = "sha256-QHWQY4703YcAEZ5qIRI3KKoK6EIMuyZL6oSfgheKmNA=";
          };
          #   dependencies = {
          #     "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
          #     "stevearc/dressing.nvim",
          #     "nvim-lua/plenary.nvim",
          #     "MunifTanjim/nui.nvim",
          #     --- The below is optional, make sure to setup it properly if you have lazy=true
          #     {
          #       'MeanderingProgrammer/render-markdown.nvim',
          #       opts = {
          #         file_types = { "markdown", "Avante" },
          #       },
          #       ft = { "markdown", "Avante" },
          #     },
          #   },
        })
        vimPlugins.nvim-web-devicons
        vimPlugins.plenary-nvim
        vimPlugins.nui-nvim
        unstable.vimPlugins.render-markdown
        # end avante
      ];
      # TODO extraPlugins.render-markdown.config = "require('render-markdown').setup({file_types = { 'markdown', 'vimwiki' },})";
    };
    # env.VIMINIT = "let \\$MYVIMRC='\\$XDG_CONFIG_HOME/nvim/init.vim' | source \\$MYVIMRC";

    environment.shellAliases = {
      vim = "nvim";
      v = "nvim";
    };
  };
}
