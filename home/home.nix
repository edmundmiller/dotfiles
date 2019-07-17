{ config, pkgs, ... }:

let
  font = "Iosevka";
  name = "Edmund Miller";
  maildir = "/home/emiller/.mail";
  dotfiles = "/home/emiller/.dotfiles";
  email = "edmund.a.miller@gmail.com";
  protonmail = "edmund.a.miller@protonmail.com";
in {
  imports = [ ./dotfiles/default.nix ./programs/vscode.nix ];

  # services.network-manager-applet.enable = true;

  manual.json.enable = true;

  # services.redshift = {
  #   enable = true;
  #   latitude = "42.698";
  #   longitude = "23.323";
  # };
  # dconf.settings =   {
  #   "org/gnome/calculator" = {
  #     button-mode = "programming";
  #     show-thousands = true;
  #     base = 10;
  #     word-size = 64;
  #   };
  # }

  accounts.email = {
    maildirBasePath = "${maildir}";
    accounts = {
      Gmail = {
        address = "${email}";
        userName = "${email}";
        flavor = "gmail.com";
        passwordCommand = "${pkgs.pass}/bin/pass gmail";
        primary = true;
        # gpg.encryptByDefault = true;
        mbsync = {
          enable = true;
          create = "both";
          expunge = "both";
          patterns = [ "*" "[Gmail]*" ]; #"[Gmail]/Sent Mail" ];
        };
        realName = "${name}";
        msmtp.enable = true;
      };
      Eman = {
        address = "eman0088@gmail.com";
        userName = "eman0088@gmail.com";
        flavor = "gmail.com";
        passwordCommand = "${pkgs.pass}/bin/pass oldGmail";
        mbsync = {
          enable = true;
          create = "both";
          expunge = "both";
          patterns = [ "*" "[Gmail]*" ]; #"[Gmail]/Sent Mail" ];
        };
        realName = "${name}";
      };
      UTD = {
        address = "Edmund.Miller@utdallas.edu";
        userName = "eam150030@utdallas.edu";
        aliases = ["eam150030@utdallas.edu"];
        flavor = "plain";
        passwordCommand = "${pkgs.pass}/bin/pass utd";
        mbsync = {
          enable = true;
          create = "both";
          expunge = "both";
          patterns = [ "*" ];
        };
        imap = {
          host = "outlook.office365.com";
          port = 993;
          tls.enable = true;
        };
        realName = "${name}";
        msmtp.enable = true;
      };
    };
  };

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
    weechat
    htop
    gitAndTools.hub
    #beets
    pass
    # pass.withExtensions ([ext.pass-import])
    nmap
    aspell
    aspellDicts.en
    aspellDicts.en-computers
    aspellDicts.en-science
    imagemagick
    mu
    isync
    tldr
    bat
    xclip
    unzip
    gibo
    youtube-dl
    (ncmpcpp.override { visualizerSupport = true; })
    # Terminals
    rxvt_unicode
    # Emacs
    ccls
    editorconfig-core-c
    pandoc
    # Apps
    atom-beta
    bookworm
    weechat
    gnucash
    libreoffice-fresh
    # keybase-gui
    calibre
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
    okular
    maim
    # Software
    conda
    # docker-compose
    python37
    python37Packages.black
    python37Packages.setuptools
    python37Packages.pyaml
    python27
    gcc
    dpkg
    borgbackup
    clangStdenv
    gnumake
    cmake
    libtool
    xonsh
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
    mbsync = { enable = true; };
    beets.enable = true;
    browserpass = {
      enable = true;
      browsers = [ "firefox" ];
    };

    texlive.enable = true;

    termite = {
      enable = true;
      font = "${font} 13";
      backgroundColor = "rgba(20, 21, 23, 0.9)";
      foregroundColor = "#c5c8c6";
      browser = "qutebrowser";
      allowBold = true;
      clickableUrl = true;
      dynamicTitle = true;
      geometry = "81x20";
      mouseAutohide = true;
      colorsExtra = ''
        color0  = #141517
        color8  = #969896
        color1  = #cc6666
        color9  = #de935f
        color2  = #b5bd68
        color10 = #757d28
        color3  = #f0c674
        color11 = #f9a03f
        color4  = #81a2be
        color12 = #2a8fed
        color5  = #b294bb
        color13 = #bc77a8
        color6  = #8abeb7
        color14 = #a3685a
        color7  = #c5c8c6
        color15 = #ffffff
      '';
    };

    git = {
      enable = true;
      lfs.enable = true;
      userName = "${name}";
      userEmail = "${protonmail}";
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

  services = {
    mbsync = {
      enable = true;
      frequency = "*:0/15";
      postExec = "${pkgs.mu}/bin/mu index -m ${maildir}";
    };
  };
}
