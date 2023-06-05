# https://github.com/hlissner/doom-emacs
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib;
with lib.my; let
  cfg = config.modules.editors.emacs;
  configDir = config.dotfiles.configDir;
in {
  options.modules.editors.emacs = {
    enable = mkBoolOpt false;
    doom = rec {
      enable = mkBoolOpt false;
      forgeUrl = mkOpt types.str "https://github.com";
      repoUrl = mkOpt types.str "${forgeUrl}/hlissner/doom-emacs";
      configRepoUrl =
        mkOpt types.str "${forgeUrl}/emiller88/doom-emacs-private";
    };
  };

  config = mkIf cfg.enable {
    nixpkgs.overlays = [inputs.emacs-overlay.overlay];

    user.packages = with pkgs; [
      ## Emacs itself
      binutils # native-comp needs 'as', provided by this
      ((emacsPackagesFor (emacs-unstable.override {withPgtk = true;})).emacsWithPackages
        (epkgs: [epkgs.vterm]))

      ## Doom dependencies
      git
      (ripgrep.override {withPCRE2 = true;})
      gnutls # for TLS connectivity

      ## Optional dependencies
      fd # faster projectile indexing
      imagemagick # for image-dired
      (mkIf (config.programs.gnupg.agent.enable)
        pinentry_emacs) # in-emacs gnupg prompts
      zstd # for undo-fu-session/undo-tree compression

      ## Module dependencies
      # :checkers spell
      (aspellWithDicts (ds: with ds; [en en-computers en-science]))
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
      # required by +jupyter
      (python3.withPackages (ps: with ps; [jupyter]))
      # Roam
      anystyle-cli
      graphviz
      (makeDesktopItem {
        name = "Org-Protocol";
        desktopName = "Org-Protocol";
        exec = "emacsclient %u";
        icon = "emacs";
        mimeTypes = ["x-scheme-handler/org-protocol"];
        categories = ["System"];
      })
      # FIXME unstable.vale
      # yaml
      nodePackages.yaml-language-server
    ];

    env.PATH = ["$XDG_CONFIG_HOME/emacs/bin"];

    modules.shell.zsh.rcFiles = ["${configDir}/emacs/aliases.zsh"];

    fonts.fonts = [pkgs.emacs-all-the-icons-fonts];

    system.userActivationScripts = mkIf cfg.doom.enable {
      installDoomEmacs = ''
        if [ ! -d "$XDG_CONFIG_HOME/emacs" ]; then
           git clone --depth=1 --single-branch "${cfg.doom.repoUrl}" "$XDG_CONFIG_HOME/emacs"
           git clone "${cfg.doom.configRepoUrl}" "$XDG_CONFIG_HOME/doom"
        fi
      '';
    };
  };
}
