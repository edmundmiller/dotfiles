{ config, lib, pkgs, ... }:

{
  nixpkgs.overlays = [
    (import (builtins.fetchTarball {
      url =
      "https://github.com/nix-community/emacs-overlay/archive/master.tar.gz";
    }))
  ];
  environment.systemPackages = with pkgs; [
    (lib.mkIf (config.programs.gnupg.agent.enable) pinentry_emacs)

    zstd
    editorconfig-core-c
    (ripgrep.override { withPCRE2 = true; })
    # Doom Emacs + dependencies
    ((emacsPackagesNgGen emacs).emacsWithPackages
    (epkgs: [ epkgs.emacs-libvterm ]))
    sqlite # :tools (lookup +docsets)
    texlive.combined.scheme-full # :lang org -- for latex previews
    ccls # :lang (cc +lsp)
    rls # :lang (rust +lsp)
    nodePackages.javascript-typescript-langserver # :lang (javascript +lsp)
    icu
    imagemagickBig
    pandoc
    aspell
    aspellDicts.en
    aspellDicts.en-computers
    aspellDicts.en-science
    languagetool
    wordnet
  ];

  fonts.fonts = [ pkgs.emacs-all-the-icons-fonts ];

  home-manager.users.emiller.xdg.configFile = {
    "zsh/rc.d/aliases.emacs.zsh".source = <config/emacs/aliases.zsh>;
    "zsh/rc.d/env.emacs.zsh".source = <config/emacs/env.zsh>;
  };
  # TODO add Doom automagically
}
