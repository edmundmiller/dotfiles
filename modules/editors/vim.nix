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
    # TODO(emiller): this module currently only manages editor package/env wiring.
    # It intentionally does NOT manage Neovim config deployment:
    # - no home.configFile."nvim" ...
    # - no home.file.".config/nvim" ...
    # - no symlink creation for config
    # TODO(emiller): if/when we Nix-manage Neovim config here, use a direct pattern:
    # home.configFile."nvim" = {
    #   source = "${config.dotfiles.configDir}/nvim";
    #   recursive = true;
    # };
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
