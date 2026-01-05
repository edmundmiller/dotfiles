# https://github.com/hlissner/doom-emacs
{
  config,
  lib,
  pkgs,
  inputs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.editors.emacs;
  inherit (config.dotfiles) configDir;
in
{
  options.modules.editors.emacs = {
    enable = mkBoolOpt false;
    doom = rec {
      enable = mkBoolOpt false;
      forgeUrl = mkOpt types.str "https://github.com";
      repoUrl = mkOpt types.str "${forgeUrl}/doomemacs/doomemacs";
      configRepoUrl = mkOpt types.str "${forgeUrl}/edmundmiller/.doom.d";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
    nixpkgs.overlays = [ inputs.emacs-overlay.overlay ];

    user.packages = with pkgs; [
      ## Emacs itself
      binutils # native-comp needs 'as', provided by this
      ((emacsPackagesFor emacs-pgtk).emacsWithPackages (
        epkgs: with epkgs; [
          vterm
          treesit-grammars.with-all-grammars
        ]
      ))

      ## Doom dependencies
      git
      (ripgrep.override { withPCRE2 = true; })
      gnutls # for TLS connectivity

      ## Optional dependencies
      fd # faster projectile indexing
      imagemagick # for image-dired
      (mkIf config.programs.gnupg.agent.enable pinentry-emacs) # in-emacs gnupg prompts
      zstd # for undo-fu-session/undo-tree compression

      ## Module dependencies
      # :checkers spell
      enchant
      (aspellWithDicts (
        ds: with ds; [
          en
          en-computers
          en-science
        ]
      ))
      nuspell
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
      # TODO: Re-enable when needed - texlive-combined is very large
      # (texlive.combine {
      #   inherit (texlive)
      #     scheme-full
      #     grffile
      #     beamertheme-metropolis
      #     wrapfig
      #     ;
      # })
      # :lang python
      pyright
      # :lang rust
      rustfmt
      unstable.rust-analyzer
      # Org, markdown, everything inbetween
      pandoc
      gnuplot
      # Roam
      anystyle-cli
      graphviz
    ]
    # required by +jupyter (only if python module is not enabled)
    ++ optionals (!config.modules.dev.python.enable) [
      (python3.withPackages (ps: with ps; [ jupyter ]))
    ]
    ++ optionals (!isDarwin) [
      # Linux-only packages
      scrot
      (makeDesktopItem {
        name = "Org-Protocol";
        desktopName = "Org-Protocol";
        exec = "emacsclient %u";
        icon = "emacs";
        mimeTypes = [ "x-scheme-handler/org-protocol" ];
        categories = [ "System" ];
      })
    ]
    ++ [
      # FIXME unstable.vale
      # yaml
      nodePackages.yaml-language-server
    ];

    env.PATH = [ "$XDG_CONFIG_HOME/emacs/bin" ];

    modules.shell.zsh.rcFiles = [ "${configDir}/emacs/aliases.zsh" ];

    fonts.packages = [
      pkgs.emacs-all-the-icons-fonts
    ] ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);
    }

    # NixOS-only activation scripts (optionalAttrs on isDarwin to avoid defining non-existent options)
    (optionalAttrs (!isDarwin) (mkIf cfg.doom.enable {
      system.userActivationScripts = {
        installDoomEmacs = ''
          if [ ! -d "$XDG_CONFIG_HOME/emacs" ]; then
             git clone --depth=1 --single-branch "${cfg.doom.repoUrl}" "$XDG_CONFIG_HOME/emacs"
             git clone "${cfg.doom.configRepoUrl}" "$XDG_CONFIG_HOME/doom"
          fi
        '';
      };
    }))
  ]);
}
