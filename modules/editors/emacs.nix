# https://github.com/hlissner/doom-emacs

{ config, lib, pkgs, inputs, ... }:

with lib;
with lib.my;
let cfg = config.modules.editors.emacs;
in
{
  options.modules.editors.emacs = {
    enable = mkBoolOpt false;
    doom = {
      enable = mkBoolOpt true;
      fromSSH = mkBoolOpt false;
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = [ inputs.emacs-overlay.overlay ];

    user.packages = with pkgs; [
      ## Emacs itself
      binutils # native-comp needs 'as', provided by this
      # 29 + pgtk + native-comp
      ((emacsPackagesFor emacsPgtkGcc).emacsWithPackages (epkgs: [
        epkgs.vterm
      ]))

      ## Doom dependencies
      git
      (ripgrep.override { withPCRE2 = true; })
      gnutls # for TLS connectivity

      ## Optional dependencies
      fd # faster projectile indexing
      imagemagick # for image-dired
      (mkIf (config.programs.gnupg.agent.enable)
        pinentry_emacs) # in-emacs gnupg prompts
      zstd # for undo-fu-session/undo-tree compression

      ## Module dependencies
      # :checkers spell
      (aspellWithDicts (ds: with ds; [ en en-computers en-science ]))
      # :checkers grammar
      languagetool
      # :tools editorconfig
      editorconfig-core-c # per-project style config
      # :tools lookup & :lang org +roam
      sqlite
      # :lang cc
      ccls
      # :lang javascript
      nodePackages.typescript-language-server
      nodePackages.typescript
      nodePackages.prettier
      # :lang latex & :lang org (latex previews)
      (texlive.combine {
        inherit (texlive) scheme-full grffile beamertheme-metropolis wrapfig;
      })
      # :lang python
      unstable.nodePackages.pyright
      # :lang rust
      rustfmt
      unstable.rust-analyzer
      # Org, markdown, everything inbetween
      pandoc
      scrot
      gnuplot
      # Roam
      graphviz
      (makeDesktopItem {
        name = "Org-Protocol";
        desktopName = "Org-Protocol";
        exec = "emacsclient %u";
        icon = "emacs";
        mimeType = "x-scheme-handler/org-protocol";
        categories = "System";
      })
      # yaml
      nodePackages.yaml-language-server
    ];

    env.PATH = [ "$XDG_CONFIG_HOME/emacs/bin" ];

    modules.shell.zsh.rcFiles = [ "${configDir}/emacs/aliases.zsh" ];

    fonts.fonts = [ pkgs.emacs-all-the-icons-fonts ];

    # init.doomEmacs = mkIf cfg.doom.enable ''
    #   if [ -d $HOME/.config/emacs ]; then
    #      ${optionalString cfg.doom.fromSSH ''
    #         git clone git@github.com:hlissner/doom-emacs.git $HOME/.config/emacs
    #         git clone git@github.com:hlissner/doom-emacs-private.git $HOME/.config/doom
    #      ''}
    #      ${optionalString (cfg.doom.fromSSH == false) ''
    #         git clone https://github.com/hlissner/doom-emacs $HOME/.config/emacs
    #         git clone https://github.com/hlissner/doom-emacs-private $HOME/.config/doom
    #      ''}
    #   fi
    # '';
  };
}
