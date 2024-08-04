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
      extraPlugins = [
        (pkgs.vimUtils.buildVimPlugin {
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
    # env.VIMINIT = "let \\$MYVIMRC='\\$XDG_CONFIG_HOME/nvim/init.vim' | source \\$MYVIMRC";

    environment.shellAliases = {
      vim = "nvim";
      v = "nvim";
    };
  };
}
