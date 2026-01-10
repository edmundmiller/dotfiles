{ lib, pkgs, ... }:
{
  imports = [
    ../_home.nix
    ./disko.nix
    ./hardware-configuration.nix
  ];

  modules = {
    desktop = {
      gnome.enable = true;

      apps.discord.enable = true;

      browsers = {
        default = "floorp";
        firefox.enable = true;
      };

      gaming.steam.enable = true;
      gaming.steam.hardware.enable = true;

      media = {
        documents.enable = true;
        # graphics.enable = true;
        mpv.enable = true;
        ncmpcpp.enable = true;
        recording.enable = true;
      };
      term = {
        default = "kitty";
        kitty.enable = true;
      };
      themes.palenight.enable = true;
    };

    editors = {
      default = "nvim";
      code.enable = true;
      emacs.enable = true;
      helix.enable = true;
      vim.enable = true;
    };
    hardware = {
      audio.enable = true;
      ergodox.enable = true;
      fs = {
        enable = true;
        zfs.enable = true;
        ssd.enable = true;
      };
      nvidia.enable = true;
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
      git.enable = true;
      gnupg.enable = true;
      pass.enable = true;
      yubikey.enable = true;
      zellij.enable = true;
      zsh.enable = true;
    };

    services = {
      docker.enable = true;
      ollama.enable = true;
      ssh.enable = true;
      syncthing.enable = true;
      tailscale.enable = true;
    };
  };

  programs.ssh.startAgent = true;
  services.openssh.startWhenNeeded = true;

  networking.hostId = "3b848ba1";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";

  user.packages = with pkgs; [ unstable.anytype ];

  # znapzend
  systemd.services.znapzend.serviceConfig.User = lib.mkForce "emiller";
  services.znapzend = {
    enable = false;
    autoCreation = true;
    zetup = {
      "tank/user/home" = {
        plan = "1d=>1h,1m=>1d,1y=>1m";
        recursive = true;
        destinations.remote = {
          host = "unas";
          dataset = "datatank/backup/meshify";
          presend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/9568367d-ab78-46e8-8301-82a3c61b9595/start";
          postsend = "${pkgs.curl}/bin/curl -m 10 --retry 5 https://hc-ping.com/9568367d-ab78-46e8-8301-82a3c61b9595";
        };
      };
    };
  };
}
