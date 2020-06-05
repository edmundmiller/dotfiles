{ config, options, lib, pkgs, ... }:
with lib; {
  options.modules.editors.emacs = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
  };
  config = mkIf config.modules.editors.emacs.enable {
    my = {
      packages = with pkgs; [
        ## Doom dependencies
        ((emacsPackagesNgGen emacsUnstable).emacsWithPackages
          (epkgs: [ epkgs.emacs-libvterm epkgs.emacsql-sqlite ]))
        git
        (ripgrep.override { withPCRE2 = true; })
        gnutls # for TLS connectivity

        fd # faster projectile indexing
        imagemagick # for image-dired
        (lib.mkIf (config.programs.gnupg.agent.enable)
          pinentry_emacs) # in-emacs gnupg prompts
        zstd # for undo-fu-session/undo-tree compression

        ## Module dependencies
        # :checkers spell
        aspell
        aspellDicts.en
        aspellDicts.en-computers
        aspellDicts.en-science
        # :checkers grammar
        languagetool
        # :tools editorconfig
        editorconfig-core-c # per-project style config
        # :tools lookup
        sqlite
        # :lang cc
        ccls
        # :lang javascript
        nodePackages.javascript-typescript-langserver
        nodePackages.vue-language-server
        nodePackages.prettier
        # :lang latex & :lang org (latex previews)
        texlive.combined.scheme-tetex
        # :lang python
        unstable.python-language-server
        # :lang rust
        rustfmt
        rls
        # Org, markdown, everything inbetween
        pandoc
        scrot
        # Roam
        (makeDesktopItem {
          name = "Org-Protocol";
          desktopName = "Org-Protocol";
          exec = "emacsclient %u";
          icon = "emacs";
          mimeType = "x-scheme-handler/org-protocol";
          categories = "Email";
        })
      ];

      env.PATH = [ "$XDG_CONFIG_HOME/emacs/bin" ];
      zsh.rc = lib.readFile <config/emacs/aliases.zsh>;
    };

    fonts.fonts = [ pkgs.emacs-all-the-icons-fonts ];
  };
}
