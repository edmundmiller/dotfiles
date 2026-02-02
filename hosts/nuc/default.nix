# Go nuc yourself
{ config, pkgs, ... }:
{
  # Workaround for nix-openclaw using bare commands (cat, ln, mkdir, rm)
  # TODO: Report upstream to nix-openclaw
  system.activationScripts.binCompat = ''
    mkdir -p /bin
    for cmd in cat ln mkdir rm; do
      ln -sf ${pkgs.coreutils}/bin/$cmd /bin/$cmd
    done
  '';

  home-manager.users.${config.user.name} = {
    # Disable dconf on headless server - no dbus session available
    dconf.enable = false;
    # Add /bin to PATH for systemd user services (openclaw wrapper uses bare 'cat')
    systemd.user.sessionVariables.PATH = "/bin:$PATH";
  };

  environment.systemPackages = with pkgs; [
    taskwarrior3
    sqlite
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
    shell = {
      bugwarrior.enable = false;
      git.enable = true;
      zsh.enable = true;
      taskwarrior = {
        enable = true;
        syncUrl = "http://localhost:8080";
        shortcuts.enable = false;
        timewarriorHook.enable = false;
      };
    };
    services = {
      audiobookshelf.enable = true;
      openclaw = {
        enable = true;
        gatewayToken = "2395843a6c856b1380154e960875c5b6cbcf238c4d26b2ef14eb2dada188f6fb";
        # No plugins for headless Linux - most need darwin
        plugins = [ ];
        telegram = {
          enable = true;
          botTokenFile = "/home/emiller/.secrets/telegram-bot-token";
          allowFrom = [ 8357890648 ]; # @edmundamiller
        };
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
      hass.enable = false;
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
