{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    mpc_cli
    (ncmpcpp.override { visualizerSupport = true; })
  ];

  services = {
    mpd = {
      enable = true;
      musicDirectory = "/data/emiller/Music/";
      startWhenNeeded = true;
      extraConfig = ''
        input {
                plugin "curl"
        }

        audio_output {
            type        "pulse"
            name        "pulse audio"
            server      "127.0.0.1"
        }

        audio_output {
            type        "fifo"
            name        "mpd_fifo"
            path        "/tmp/mpd.fifo"
            format      "44100:16:2"
        }
      '';
    };
  };

  hardware.pulseaudio.tcp = {
    enable = true;
    anonymousClients.allowedIpRanges = [ "127.0.0.1" ];
  };

  users.users.emiller.extraGroups = [ "mpd" ];

  home-manager.users.emiller = {
    programs = { beets.enable = true; };

    xdg.configFile = {
      "zsh/rc.d/aliases.ncmpcpp.zsh".source = <config/ncmpcpp/aliases.zsh>;
      "zsh/rc.d/env.ncmpcpp.zsh".source = <config/ncmpcpp/env.zsh>;
      "ncmpcpp/config".source = <config/ncmpcpp/config>;
      "ncmpcpp/bindings".source = <config/ncmpcpp/bindings>;
      "ncmpcpp/mpdnotify.conf".source = <config/ncmpcpp/mpdnotify.conf>;
    };
  };
}
