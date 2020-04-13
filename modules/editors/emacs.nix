{ config, lib, pkgs, ... }: {
  my = {
    packages = with pkgs; [
      ## Doom dependencies
      ((emacsPackagesNgGen emacsUnstable).emacsWithPackages
        (epkgs: [ epkgs.emacs-libvterm epkgs.emacsql-sqlite ]))
      git
      (ripgrep.override { withPCRE2 = true; })

      ## Optional dependencies
      editorconfig-core-c # per-project style config
      fd # faster projectile indexing
      gnutls # for TLS connectivity
      imagemagick # for image-dired
      (lib.mkIf (config.programs.gnupg.agent.enable)
        pinentry_emacs) # in-emacs gnupg prompts
      zstd # for undo-tree compression

      ## Module dependencies
      # :checkers spell
      aspell
      aspellDicts.en
      aspellDicts.en-computers
      aspellDicts.en-science
      # :checkers grammar
      languagetool
      # :tools lookup
      sqlite
      # :lang cc
      ccls
      # :lang javascript
      nodePackages.javascript-typescript-langserver
      nodePackages.vue-language-server
      nodePackages.prettier
      # :lang latex & :lang org (latex previews)
      texlive.combined.scheme-medium
      # :lang rust
      rustfmt
      rls
      # Org, markdown, everything inbetween
      pandoc
    ];

    env.PATH = [ "$HOME/.emacs.d/bin" ];
    zsh.rc = lib.readFile <config/emacs/aliases.zsh>;
  };

  fonts.fonts = [ pkgs.emacs-all-the-icons-fonts ];
}
