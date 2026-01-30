{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.services.mpd;
in
{
  options.modules.services.mpd = {
    enable = mkBoolOpt false;
    scrobbling.enable = mkBoolOpt false;
  };

  config = mkIf cfg.enable (mkMerge [
    {
      user.packages = with pkgs; [
        mpc_cli
        ncpamixer
      ];

      user.extraGroups = [ "mpd" ];

      home-manager.users.${config.user.name}.programs.beets = {
        enable = true;
        settings = {
          plugins = "missing chroma convert duplicates fetchart embedart lastgenre";
          directory = "/data/media/music";
          library = "/data/media/music/beets.db";
          paths = {
            default = "$albumartist/$album/$track - $title";
            singleton = "$artist/singles/$title";
          };
          original_date = true;
          import.move = true;
          import.copy = false;
          lastgenre.count = 10;
        };
      };

      environment.variables.MPD_HOME = "$XDG_CONFIG_HOME/mpd";

      services = {
        mpd = {
          enable = true;
          musicDirectory = "/data/media/music";
          user = "${config.user.name}";
          extraConfig = ''
            audio_output {
              type "pipewire"
              name "My PipeWire Output"
            }
          '';
        };
      };
      systemd.services.mpd.environment = {
        # https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/609
        XDG_RUNTIME_DIR = "/run/user/1000"; # User-id 1000 must match above user. MPD will look inside this directory for the PipeWire socket.
      };
    }

    (mkIf cfg.scrobbling.enable {
      services.mpdscribble = {
        enable = true;
        endpoints = {
          "last.fm" = {
            passwordFile = config.age.secrets.lastfm-password.path;
            username = "emiller88";
          };
        };
      };
    })
  ]);
}
