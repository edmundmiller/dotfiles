# Go nuc yourself
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:
{
  # Workaround for nix-clawdbot using bare commands (cat, ln, mkdir, rm)
  # TODO: Report upstream to nix-clawdbot
  system.activationScripts.binCompat = ''
    mkdir -p /bin
    for cmd in cat ln mkdir rm; do
      ln -sf ${pkgs.coreutils}/bin/$cmd /bin/$cmd
    done
  '';

  home-manager.users.${config.user.name} = {
    # Disable dconf on headless server - no dbus session available
    dconf.enable = false;
    # Add core system paths for systemd user services (clawdbot wrapper uses bare 'cat')
    systemd.user.sessionVariables.PATH = "/run/current-system/sw/bin:/bin:$PATH";
    home.activation.clawdbotEnv = inputs.home-manager.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.coreutils}/bin/mkdir -p "${config.user.home}/.clawdbot"
      ${lib.optionalString
        (config ? age && config.age ? secrets && config.age.secrets ? "clawdbot-bridge-token")
        ''
          if [ -f ${config.age.secrets.clawdbot-bridge-token.path} ]; then
            token="$(${pkgs.coreutils}/bin/cat ${config.age.secrets.clawdbot-bridge-token.path})"
            printf 'CLAWDBOT_GATEWAY_TOKEN=%s\n' "$token" > "${config.user.home}/.clawdbot/.env"
            ${pkgs.coreutils}/bin/chmod 600 "${config.user.home}/.clawdbot/.env"
          fi
        ''
      }
    '';
  };

  environment.systemPackages = with pkgs; [

    sqlite
    openssl
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
      git.enable = true;
      pi.enable = true;
      zsh.enable = true;
    };
    dev = {
      node = {
        enable = true;
        enableGlobally = true;
      };
    };
    services = {
      audiobookshelf.enable = true;
      clawdbot = {
        enable = true;
        anthropic.apiKeyFile = config.age.secrets.anthropic-api-key.path;
        configOverrides = {
          gateway = {
            mode = "local";
            bind = "tailnet";
            auth = {
              mode = "token";
              token = "\${CLAWDBOT_GATEWAY_TOKEN}";
              allowTailscale = true;
            };
            tailscale.mode = "off";
          };
          bridge = {
            enabled = true;
            port = 18790;
            bind = "tailnet";
            tls = {
              enabled = true;
              autoGenerate = true;
            };
          };
        };
        # Disable all plugins - most have darwin-only deps
        plugins = {
          bird = false;
          camsnap = false;
          gogcli = false;
          imsg = false;
          oracle = false;
          peekaboo = false; # pulls in darwin deps
          poltergeist = false;
          sag = false;
          summarize = false;
        };
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
      taskchampion.enable = false;
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
