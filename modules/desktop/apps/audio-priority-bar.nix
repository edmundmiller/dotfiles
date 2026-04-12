{
  config,
  lib,
  pkgs,
  isDarwin,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.desktop.apps.audioPriorityBar;

  mkArrayWrite =
    key: values:
    let
      rendered = concatStringsSep " " (map escapeShellArg values);
    in
    if values == [ ] then
      ''
        /usr/bin/defaults write app.audioprioritybar ${key} -array
      ''
    else
      ''
        /usr/bin/defaults write app.audioprioritybar ${key} -array ${rendered}
      '';
in
{
  options.modules.desktop.apps.audioPriorityBar = {
    enable = mkBoolOpt false;

    inputPriorities = mkOption {
      type = types.listOf types.str;
      description = "Ordered list of CoreAudio input device UIDs for AudioPriorityBar.";
      default = [
        "AppleUSBAudioEngine:Shure Inc:Shure MV7:20232000:2,1"
        "AppleUSBAudioEngine:Shure Inc:Shure MV7:144000:2,1"
        "AppleUSBAudioEngine:Shure Inc:Shure MV7:20232000:3,2"
        "AppleUSBAudioEngine:Razer Inc.:Razer Seiren V3 Mini:110000:1"
        "AppleUSBAudioEngine:Unknown Manufacturer:MX Brio:2522LVP1VGL8:5"
        "AppleUSBAudioEngine:Unknown Manufacturer:Logitech StreamCam:623EC745:3"
        "BuiltInMicrophoneDevice"
        "34-0E-22-1E-BE-44:input"
        "0518F0DA-FD70-47AE-951E-692100000003"
        "AppleUSBAudioEngine:Generic:USB Audio:20234000:1"
        "ShureVirtualAudioDevice_UID"
        "AppleUSBAudioEngine:Generic:USB Audio:200901010001:1"
        "46264E0F-5044-42F2-AD00-846600000003"
      ];
    };

    speakerPriorities = mkOption {
      type = types.listOf types.str;
      description = "Ordered list of CoreAudio output UIDs in AudioPriorityBar speaker mode.";
      default = [ ];
    };

    headphonePriorities = mkOption {
      type = types.listOf types.str;
      description = "Ordered list of CoreAudio output UIDs in AudioPriorityBar headphone mode.";
      default = [ ];
    };
  };

  config = optionalAttrs isDarwin (
    mkIf cfg.enable {
      environment.systemPackages = [ pkgs.my.audio-priority-bar ];

      home-manager.users.${config.user.name} =
        { lib, ... }:
        {
          home.activation.audioPriorityBarDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            # Ensure AudioPriorityBar device priorities are declaratively seeded.
            ${mkArrayWrite "inputPriorities" cfg.inputPriorities}
            ${mkArrayWrite "speakerPriorities" cfg.speakerPriorities}
            ${mkArrayWrite "headphonePriorities" cfg.headphonePriorities}
          '';
        };
    }
  );
}
