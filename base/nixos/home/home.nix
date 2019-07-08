{ config, pkgs, ... }:

let
  font = "Iosevka";
in {
  imports = [ ./programs/vscode.nix ./dotfiles/default.nix ];

  # services.network-manager-applet.enable = true;

  # services.redshift = {
  #   enable = true;
  #   latitude = "42.698";
  #   longitude = "23.323";
  # };

  gtk = {
    enable = true;
    theme = {
      package = pkgs.sierra-gtk-theme;
      name = "Sierra-compact-dark";
    };
    iconTheme = {
      package = pkgs.paper-icon-theme;
      name = "Paper-Mono-Dark";
    };
    # Give Termite some internal spacing.
    gtk3.extraCss = ".termite {padding: 20px;}";
  };

  home.packages = with pkgs; [
    # Browsers
    brave
    qutebrowser
    # Nix stuff
    appimage-run
    cachix
    # CLI utils
    htop
    gitAndTools.hub
    #beets
    pass
    nmap
    tldr
    bat
    xclip
    gibo
    youtube-dl
    (ncmpcpp.override { visualizerSupport = true; })
    # Terminals
    rxvt_unicode
    termite
    # Emacs
    ccls
    editorconfig-core-c
    # Apps
    gnucash
    # keybase-gui
    discord
    dropbox
    gimp
    spotify
    obs-studio
    transmission
    zoom-us
    # Desktop
    networkmanagerapplet
    # autorandr
    mpv
    ffmpeg
    rofi-pass
    gnomeExtensions.topicons-plus
    gnomeExtensions.mediaplayer
    networkmanager-openconnect
    # IDK What these are
    pavucontrol
    units
    binutils
    tetex
    okular
    maim
    # Software
    conda
    docker-compose
    python37
    python27
    gcc
    dpkg
    borgbackup
    clangStdenv
    gnumake
    cmake
    libtool
    # haskell
    cabal-install
    cabal2nix
    haskellPackages.styx
    ghc
    hlint
    haskellPackages.hindent
    # (pkgs.haskellPackages.callCabal2nix "fullwidth" ~/projects/fullwidth {})
    # (pkgs.haskellPackages.callCabal2nix "polishnt" ~/projects/polishnt {})
    # Node
    yarn
    # nodejs-12_x
    nodejs-10_x
    # Rust
    rustup
    cargo

    # Graveyard
    # dunst
    # libnotify
    # i3lock-fancy
  ];

  nixpkgs.config = {
    allowUnfree = true;
    firefox.enableGnomeExtensions = true;

    yarn = pkgs.yarn.override { nodejs = pkgs.nodejs-12_x; };
  };
  programs = {
    # mbsync = { enable = true; };

    termite = {
      enable = true;
      font = "${font} 13";
      backgroundColor = "rgba(32, 39, 51, 0.9)";
    };

    git = {
      enable = true;
      lfs.enable = true;
      userName = "Edmund Miller";
      userEmail = "edmund.a.miller@protonmail.com";
      signing.key = "BC10AA9D";
      signing.signByDefault = true;
      aliases = {
        amend = "commit --amend";
        exec = "!exec ";
        lg =
        "log --color --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --";
        ls = "ls-files";
        orphan = "checkout --orphan";
        unadd = "reset HEAD";
        undo-commit = ''
          reset --soft "HEAD^"
                    mr = !sh -c 'git fetch $1 merge-requests/$2/head:mr-$1-$2 && git checkout mr-$1-$2' -'';
        # data analysis
        ranked-authors = "!git authors | sort | uniq -c | sort -n";
        emails = ''!git log --format="%aE" | sort -u'';
        email-domains =
        ''!git log --format="%aE" | awk -F'@' '{print $2}' | sort -u'';
      };
      extraConfig = ''
        [github]
          user = emiller88
        [color]
          ui = auto
        [rebase]
          autosquash = true
        [push]
          default = current
        [merge]
          ff = onlt
          log = true
      '';
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
    };
    # Let Home Manager install and manage itself.
    home-manager.enable = true;
  };

}
