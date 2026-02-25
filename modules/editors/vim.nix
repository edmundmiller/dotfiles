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
    package = mkOpt types.package pkgs.neovim;
  };

  config = mkIf cfg.enable {
    user.packages = [
      cfg.package
      pkgs.editorconfig-core-c
      # ctags provided by emacs package
      pkgs.unstable.lua-language-server
      pkgs.lazygit
      pkgs.fd
      (pkgs.ripgrep.override { withPCRE2 = true; })
      pkgs.gnumake
      pkgs.unzip
    ];

    environment.shellAliases = {
      vim = "nvim";
    };

    # v: open cwd when called bare, pass args otherwise (from omarchy's n())
    modules.shell.zsh.rcInit = ''
      v() { if [[ $# -eq 0 ]]; then command nvim .; else command nvim "$@"; fi; }
    '';

    # Set nvim as the default editor
    env = {
      EDITOR = mkDefault "nvim";
      VISUAL = mkDefault "nvim";
    };

  };
}
