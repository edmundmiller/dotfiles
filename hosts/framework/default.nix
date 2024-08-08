# Framework -- my laptop
{ lib, pkgs, ... }:
{
  imports = [
    ../home.nix
    ./hardware-configuration.nix
  ];

  modules = {
    desktop = {
      gnome.enable = true;
      cosmic.enable = true;

      apps.discord.enable = true;
      apps.mail.accounts.enable = true;
      apps.mail.aerc.enable = true;

      browsers = {
        default = "floorp";
        firefox.enable = true;
      };

      media = {
        documents.enable = true;
        documents.pdf.enable = true;
        graphics.enable = true;
        graphics.raster.enable = false;
        graphics.sprites.enable = false;
        mpv.enable = true;
        ncmpcpp.enable = true;
        spotify.enable = true;
      };
      term = {
        default = "ghostty";
        kitty.enable = true;
        ghostty.enable = true;
        wezterm.enable = true;
      };
      themes.palenight.enable = true;
    };

    editors = {
      default = "nvim";
      # code.enable = true;
      emacs.enable = true;
      helix.enable = true;
      vim.enable = true;
    };

    hardware = {
      audio.enable = true;
      audio.easyeffects.enable = true;
      bluetooth.enable = true;
      ergodox.enable = true;
      fs = {
        enable = true;
        zfs.enable = true;
        ssd.enable = true;
      };
      printing.enable = true;
      sensors.enable = true;
    };
    dev = {
      cc.enable = true;
      julia.enable = true;
      nextflow.enable = true;
      nixlang.enable = true;
      node.enable = true;
      node.enableGlobally = true;
      python.enable = true;
      python.conda.enable = true;
      R.enable = true;
      rust.enable = true;
    };

    shell = {
      "1password".enable = true;
      age.enable = true;
      direnv.enable = true;
      nushell.enable = false;
      git.enable = true;
      gnupg.enable = true;
      pass.enable = true;
      tmux.enable = true;
      zsh.enable = true;
    };

    services = {
      comin.enable = true;
      docker.enable = true;
      ssh.enable = true;
      syncthing.enable = true;
      tailscale.enable = true;
    };

    theme.active = "functional";
  };

  programs.ssh.startAgent = true;
  services.openssh.startWhenNeeded = true;

  networking.hostId = "0dd71c1c";
  networking.networkmanager.enable = true;
  programs.nm-applet.enable = true;
  users.users.emiller.extraGroups = [
    "input"
    "networkmanager"
  ];

  time.timeZone = "America/Chicago";
  time.hardwareClockInLocalTime = true;
  location.provider = "geoclue2";

  # Random laptop specific packages that don't need a whole module
  user.packages = with pkgs; [
    tauon
    unstable.thunderbird
    my.catgpt
    unstable.ticktick
    unstable.zed-editor
  ];

  # Mount iPhone
  services.usbmuxd.enable = true;

  environment.systemPackages = with pkgs; [
    libimobiledevice
    ifuse # optional, to mount using 'ifuse'
  ];

  systemd.services.znapzend.serviceConfig.User = lib.mkForce "emiller";
  services.znapzend = {
    enable = true;
    autoCreation = true;
    zetup = {
      "tank/user/home" = {
        plan = "1d=>1h,1m=>1d,1y=>1m";
        recursive = true;
        destinations.remote = {
          host = "unas";
          dataset = "datatank/backup/framework";
          presend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/bfadc7f9-92d5-4d23-b2b7-a1f39a550f41/start";
          postsend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/bfadc7f9-92d5-4d23-b2b7-a1f39a550f41/$?";
        };
      };
    };
  };
}
