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
  defaultsDomain = "com.example.AudioPriorityBar";

  mkArrayWrite =
    key: values:
    let
      rendered = concatStringsSep " " (map escapeShellArg values);
    in
    if values == [ ] then
      ''
        /usr/bin/defaults write ${defaultsDomain} ${key} -array
      ''
    else
      ''
        /usr/bin/defaults write ${defaultsDomain} ${key} -array ${rendered}
      '';

  inputPriorityFile = pkgs.writeText "audio-input-priorities" (
    concatStringsSep "\n" cfg.inputPriorities + "\n"
  );

  inputPrioritySorter = pkgs.writeShellApplication {
    name = "audio-input-priority-sorter";
    runtimeInputs = [
      pkgs.jq
      pkgs.switchaudio-osx
    ];
    text = ''
      switch_audio="''${SWITCH_AUDIO_SOURCE_BIN:-${pkgs.switchaudio-osx}/bin/SwitchAudioSource}"
      mode="watch"
      priority_file=""

      usage() {
        echo "usage: audio-input-priority-sorter [--once|--watch] --priorities-file PATH" >&2
      }

      while (( $# > 0 )); do
        case "$1" in
          --once)
            mode="once"
            shift
            ;;
          --watch)
            mode="watch"
            shift
            ;;
          --priorities-file)
            if (( $# < 2 )); then
              usage
              exit 64
            fi
            priority_file="$2"
            shift 2
            ;;
          --help|-h)
            usage
            exit 0
            ;;
          *)
            usage
            exit 64
            ;;
        esac
      done

      if [[ -z "$priority_file" || ! -r "$priority_file" ]]; then
        echo "audio input priority file is not readable" >&2
        exit 66
      fi

      reconcile() {
        local report_unchanged="$1"
        local devices current current_uid candidate desired desired_name readback readback_uid current_name

        if ! devices="$($switch_audio -a -t input -f json)"; then
          echo "failed to enumerate audio inputs" >&2
          return 1
        fi
        if ! current="$($switch_audio -c -t input -f json)"; then
          echo "failed to read the default audio input" >&2
          return 1
        fi
        if ! current_uid="$(jq -er '.uid' <<< "$current")"; then
          echo "default audio input readback did not include a UID" >&2
          return 1
        fi

        desired=""
        while IFS= read -r candidate || [[ -n "$candidate" ]]; do
          if [[ -z "$candidate" || "$candidate" == \#* ]]; then
            continue
          fi
          if jq -s -e --arg uid "$candidate" 'any(.[]; .uid == $uid)' \
            >/dev/null <<< "$devices"; then
            desired="$candidate"
            break
          fi
        done < "$priority_file"

        if [[ -z "$desired" ]]; then
          if [[ "$report_unchanged" == "true" ]]; then
            current_name="$(jq -r '.name // "current input"' <<< "$current")"
            printf 'no configured preferred input is available; leaving input: %s\n' "$current_name"
          fi
          return 0
        fi

        desired_name="$(jq -sr --arg uid "$desired" 'map(select(.uid == $uid))[0].name // "configured input"' <<< "$devices")"
        if [[ "$current_uid" == "$desired" ]]; then
          if [[ "$report_unchanged" == "true" ]]; then
            printf 'input already preferred: %s\n' "$desired_name"
          fi
          return 0
        fi

        if ! "$switch_audio" -t input -u "$desired" >/dev/null; then
          echo "failed to select the preferred audio input" >&2
          return 1
        fi
        if ! readback="$($switch_audio -c -t input -f json)" \
          || ! readback_uid="$(jq -er '.uid' <<< "$readback")" \
          || [[ "$readback_uid" != "$desired" ]]; then
          echo "preferred audio input failed authoritative readback" >&2
          return 1
        fi

        printf 'selected preferred input: %s\n' "$desired_name"
      }

      if [[ "$mode" == "once" ]]; then
        reconcile true
        exit
      fi

      while true; do
        reconcile false || true
        sleep 2
      done
    '';
  };
in
{
  options.modules.desktop.apps.audioPriorityBar = {
    enable = mkBoolOpt false;

    inputPriorities = mkOption {
      type = types.listOf types.str;
      description = "Ordered list of CoreAudio input device UIDs for AudioPriorityBar.";
      default = [
        "AppleUSBAudioEngine:DJI Technology Co., Ltd.:Wireless Mic Rx:XSP12345678B:3"
        "AppleUSBAudioEngine:Shure Inc:Shure MV7:20232000:2,1"
        "AppleUSBAudioEngine:Shure Inc:Shure MV7:144000:2,1"
        "AppleUSBAudioEngine:Shure Inc:Shure MV7:20232000:3,2"
        "AppleUSBAudioEngine:Razer Inc.:Razer Seiren V3 Mini:110000:1"
        "AppleUSBAudioEngine:Unknown Manufacturer:MX Brio:2522LVP1VGL8:5"
        "AppleUSBAudioEngine:Unknown Manufacturer:Logitech StreamCam:623EC745:3"
        # Moni's webcam
        "AppleUSBAudioEngine:Unknown Manufacturer:Logitech StreamCam:A7626075:3"
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

      launchd.user.agents.audio-priority-bar = {
        serviceConfig = {
          Program = "${inputPrioritySorter}/bin/audio-input-priority-sorter";
          ProgramArguments = [
            "${inputPrioritySorter}/bin/audio-input-priority-sorter"
            "--watch"
            "--priorities-file"
            (toString inputPriorityFile)
          ];
          RunAtLoad = true;
          KeepAlive = true;
          ProcessType = "Interactive";
          StandardOutPath = "${config.user.home}/Library/Logs/audio-input-priority-sorter.log";
          StandardErrorPath = "${config.user.home}/Library/Logs/audio-input-priority-sorter.err.log";
        };
      };

      home-manager.users.${config.user.name} =
        { lib, ... }:
        {
          home.activation.audioPriorityBarDefaults = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            # Ensure AudioPriorityBar device priorities are declaratively seeded.
            ${mkArrayWrite "inputPriorities" cfg.inputPriorities}
            ${mkArrayWrite "speakerPriorities" cfg.speakerPriorities}
            ${mkArrayWrite "headphonePriorities" cfg.headphonePriorities}
            # The GUI remains available for inspection/manual selection, but
            # the input-only launch agent owns automatic switching.
            /usr/bin/defaults write ${defaultsDomain} customMode -bool true
          '';
        };
    }
  );
}
