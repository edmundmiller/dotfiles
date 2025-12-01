{
  config,
  options,
  lib,
  pkgs,
  inputs,
  isDarwin,
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

  # Use home-manager module for cross-platform compatibility
  imports = optionals (!isDarwin) [ inputs.nixvim.nixosModules.nixvim ];

  config = mkIf cfg.enable (mkMerge [
    {
      user.packages = with pkgs; [
        editorconfig-core-c
        # inputs.neovim-nightly-overlay.packages.${pkgs.system}.default
        ctags
        unstable.lua-language-server
        lazygit
      ];

      environment.shellAliases = {
        vim = "nvim";
        v = "nvim";
      };

      # Set nvim as the default editor
      env = {
        EDITOR = "nvim";
        VISUAL = "nvim";
      };
    }

    # NixOS-specific nixvim configuration
    (optionalAttrs (!isDarwin) {
      programs.nixvim = {
        enable = true;
        # vimdiffAlias = true;
        clipboard.register = "unnamedplus";
        vimAlias = true;
        editorconfig.enable = true;
        globals.mapleader = "<space>";
        # filetype =  { "markdown", "Avante" };
        opts = {
          # Avante
          laststatus = 3;
          splitkeep = "screen";
        };
        plugins = {
          copilot-chat.enable = true;
          copilot-lua.enable = true;
          direnv.enable = true;
          dressing.enable = true;
          harpoon.enable = true;
          harpoon.enableTelescope = true;
          neoscroll.enable = true;
          neotest.enable = true;
          telescope.enable = true;
          treesitter.enable = true;
          treesitter.folding = true;
          treesitter-textobjects.enable = true;
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
        ];
      };
    })
  ]);
}
