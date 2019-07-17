{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    editorconfig-core-c
    # Doom Emacs + dependencies
    ((emacsPackagesNgGen emacs).emacsWithPackages
    (epkgs: [ epkgs.emacs-libvterm ]))
    sqlite                          # :tools (lookup +docsets)
    texlive.combined.scheme-medium  # :lang org -- for latex previews
    ccls                            # :lang (cc +lsp)
  ];

  fonts.fonts = [ pkgs.emacs-all-the-icons-fonts ];

  home-manager.users.emiller.xdg.configFile = {
    "zsh/rc.d/aliases.emacs.zsh".source = <config/emacs/aliases.zsh>;
    "zsh/rc.d/env.emacs.zsh".source = <config/emacs/env.zsh>;
  };
}
