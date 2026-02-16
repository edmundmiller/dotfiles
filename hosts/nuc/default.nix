# Go nuc yourself
{
  config,
  inputs,
  pkgs,
  system,
  ...
}:
{
  # Workaround for nix-openclaw using bare commands (cat, ln, mkdir, rm)
  # TODO: Report upstream to nix-openclaw
  system.activationScripts.binCompat = ''
    mkdir -p /bin
    for cmd in cat ln mkdir rm; do
      ln -sf ${pkgs.coreutils}/bin/$cmd /bin/$cmd
    done

  '';

  # nix-ld libraries for dynamically linked binaries (e.g. sag TTS)
  programs.nix-ld.libraries = with pkgs; [
    alsa-lib # libasound.so.2 for sag audio playback
  ];

  home-manager.users.${config.user.name} = {
    # Disable dconf on headless server - no dbus session available
    dconf.enable = false;
    # Ensure systemd user services can find system + user packages (openclaw uses bare 'cat')
    systemd.user.sessionVariables.PATH = "/bin:/run/current-system/sw/bin:/etc/profiles/per-user/${config.user.name}/bin";
  };

  environment.systemPackages = with pkgs; [
    taskwarrior3
    sqlite
    chromium # For openclaw browser
    nodejs # For openclaw plugins
    python3 # For node-gyp (pi-interactive-shell/node-pty)
    gcc
    gnumake # For node-gyp native compilation
    cmake # For node-llama-cpp (qmd dependency)
    claude-code # CLI backend for openclaw
    codex # CLI backend for openclaw
    bun # For pi CLI backend (npm: @mariozechner/pi-coding-agent)
    inputs.nix-steipete-tools.packages.${system}.sag # TTS for openclaw sag plugin
  ];
  imports = [
    ../_server.nix
    ../_home.nix
    ./hardware-configuration.nix
    ./disko.nix
    ./backups.nix
  ];

  ## Modules
  modules = {
    editors = {
      default = "nvim";
      vim.enable = true;
    };
    hardware = {
      bluetooth.enable = true;
      fs = {
        enable = true;
        zfs.enable = true;
        ssd.enable = true;
      };
    };
    dev = {
      node = {
        enable = true;
        enableGlobally = true;
      };
    };
    shell = {
      # bugwarrior.enable = false;  # Module removed
      git.enable = true;
      zsh.enable = true;
      pi.enable = true;
      ai = {
        enable = true;
        enableClaude = true;
        enableCodex = true;
      };
      # taskwarrior module removed - TODO restore when available
      # taskwarrior = {
      #   enable = true;
      #   syncUrl = "http://localhost:8080";
      #   shortcuts.enable = false;
      #   timewarriorHook.enable = false;
      # };
    };
    services = {
      audiobookshelf.enable = true;
      openclaw = {
        enable = true;
        gatewayTokenFile = config.age.secrets.openclaw-gateway-token.path;
        plugins = [
          {
            source = "github:edmundmiller/dotfiles/415e35c2e9addcad8c600bcb8ada8ce1a8497077?dir=tools/linear&narHash=sha256-wd7FfzCzZzY0rZrPAAJrYJjMZzenewXfipD4XCc/mH8%3D";
            config.env.LINEAR_API_TOKEN_FILE = config.age.secrets.linear-api-token.path;
          }
        ];
        telegram = {
          enable = true;
          botTokenFile = "/home/emiller/.secrets/telegram-bot-token";
          allowFrom = [ 8357890648 ]; # @edmundamiller
        };
        sharedSkills = [
          "ast-grep"
          "beads"
          "code-search"
          "jut"
          "pr-review"
          "python-scripts"
        ];
        skills = [
          {
            name = "obsidian-vault";
            description = "Access Edmund's Obsidian vault for notes, projects, and knowledge base";
            mode = "inline";
            body = ''
              # Obsidian Vault Access

              Location: `/home/emiller/obsidian-vault`

              ## Structure (PARA method)
              - `00_Inbox/` - New notes, quick captures
              - `01_Projects/` - Active projects with tasks
              - `02_Areas/` - Ongoing areas of responsibility
              - `03_Resources/` - Reference material, topics of interest
              - `04_Archive/` - Completed/inactive items
              - `05_Attachments/` - Images, PDFs, files
              - `06_Metadata/` - Templates, config

              ## How to Search
              ```bash
              rg "search term" /home/emiller/obsidian-vault
              rg -l "search term" /home/emiller/obsidian-vault  # list files only
              ```

              ## How to Read/List
              ```bash
              cat "/home/emiller/obsidian-vault/path/to/note.md"
              ls /home/emiller/obsidian-vault/01_Projects/
              ```
            '';
          }
        ];
      };
      docker.enable = true;
      hass = {
        enable = true;
        postgres.enable = true;
        homebridge.enable = true;
        homebridge.tailscaleService.enable = true;
        tailscaleService.enable = true;
      };
      homepage.enable = true;
      jellyfin.enable = true;
      prowlarr.enable = true;
      qb.enable = false;
      radarr.enable = true;
      sonarr.enable = true;
      deploy-rs.enable = true;
      ssh.enable = true;
      syncthing.enable = false;
      tailscale.enable = true;
      taskchampion.enable = true;
      obsidian-sync.enable = true;
      opencode.enable = true;
      timew_sync.enable = true;
      transmission.enable = false;
    };

    # theme.active = "alucard";
  };

  time.timeZone = "America/Chicago";

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  # FIXME https://discourse.nixos.org/t/logrotate-config-fails-due-to-missing-group-30000/28501/7
  services.logrotate.checkConfig = false;

  users.users.emiller.hashedPasswordFile = config.age.secrets.emiller_password.path;

  # systemd.services.znapzend.serviceConfig.User = lib.mkForce "emiller";
  services.znapzend = {
    # FIXME
    enable = false;
    autoCreation = true;
    zetup = {
      "tank/user/home" = {
        plan = "1d=>1h,1m=>1d,1y=>1m";
        recursive = true;
        destinations.local = {
          dataset = "datatank/backup/unas";
          presend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/ccb26fbc-95af-45bb-b4e6-38da23db6893/start";
          postsend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/ccb26fbc-95af-45bb-b4e6-38da23db6893";
        };
      };
    };
  };
}
