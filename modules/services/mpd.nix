{ config, lib, pkgs, ... }:

{
  my = {
    packages = with pkgs; [
      mpc_cli
      (ncmpcpp.override { visualizerSupport = true; })
    ];

    user.extraGroups = [ "mpd" ];

    home.programs.beets.enable = true;
  };

  services = {
    mpd = {
      enable = true;
      musicDirectory = "/data/media/music";
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
}
