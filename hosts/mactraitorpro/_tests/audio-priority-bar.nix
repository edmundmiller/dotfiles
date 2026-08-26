# Pure Nix/build regression: keep the input sorter continuous and input-only.
{
  darwinConfig,
  pkgs,
}:
let
  inherit (builtins) filter length;
  inherit (pkgs.lib.strings) concatStringsSep hasInfix;

  mac = darwinConfig.config;
  activation = mac.home-manager.users.${mac.user.name}.home.activation.audioPriorityBarDefaults.data;
  launchAgent = mac.launchd.user.agents."audio-priority-bar";
  service = launchAgent.serviceConfig;
  program = service.Program;
  inputPriorities = concatStringsSep "\n" mac.modules.desktop.apps.audioPriorityBar.inputPriorities;

  assertions = [
    {
      test = hasInfix "/usr/bin/defaults write com.example.AudioPriorityBar" activation;
      msg = "the activation must write the installed app's defaults domain";
    }
    {
      test = !hasInfix "/usr/bin/defaults write app.audioprioritybar" activation;
      msg = "the activation must not write the obsolete defaults domain";
    }
    {
      test = hasInfix "customMode -bool true" activation;
      msg = "the GUI app must remain in manual mode so it cannot auto-switch outputs";
    }
    {
      test = service.RunAtLoad && service.KeepAlive;
      msg = "the input sorter must launch at login and restart after an exit";
    }
    {
      test = hasInfix "/bin/audio-input-priority-sorter" program;
      msg = "the launch agent must execute the repo-owned input sorter";
    }
    {
      test = builtins.elem "--watch" service.ProgramArguments;
      msg = "the launch agent must run the sorter continuously";
    }
    {
      test = builtins.all builtins.isString service.ProgramArguments;
      msg = "every launch agent argument must be plist-serializable as a string";
    }
    {
      test = hasInfix ''
        AppleUSBAudioEngine:Unknown Manufacturer:Logitech StreamCam:623EC745:3
        AppleUSBAudioEngine:Unknown Manufacturer:Logitech StreamCam:A7626075:3
        BuiltInMicrophoneDevice
      '' inputPriorities;
      msg = "Moni's webcam must be the final webcam priority before the built-in microphone";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;

  fakeSwitchAudioSource = pkgs.writeShellScript "fake-switch-audio-source" ''
    set -euo pipefail
    state="''${SWITCH_AUDIO_TEST_STATE:?}"
    log="''${SWITCH_AUDIO_TEST_LOG:?}"
    printf '%s\n' "$*" >> "$log"

    if [[ "$*" == "-a -t input -f json" ]]; then
      printf '%s\n' \
        '{"name":"Fallback","type":"input","uid":"fallback"}' \
        '{"name":"Preferred","type":"input","uid":"preferred"}'
      exit 0
    fi
    if [[ "$*" == "-c -t input -f json" ]]; then
      uid="$(<"$state")"
      if [[ "$uid" == "preferred" ]]; then
        printf '%s\n' '{"name":"Preferred","type":"input","uid":"preferred"}'
      else
        printf '%s\n' '{"name":"Fallback","type":"input","uid":"fallback"}'
      fi
      exit 0
    fi
    if [[ "$1" == "-t" && "$2" == "input" && "$3" == "-u" ]]; then
      printf '%s\n' "$4" > "$state"
      exit 0
    fi

    echo "unexpected SwitchAudioSource arguments" >&2
    exit 64
  '';

  testPriorities = pkgs.writeText "audio-input-priority-test-list" ''
    preferred
    fallback
  '';
in
pkgs.runCommand "audio-priority-bar-regressions"
  {
    passthru = {
      inherit assertions failures;
    };
  }
  ''
    if [ ${toString (length failures)} -ne 0 ]; then
      echo "${toString (length failures)} AudioPriorityBar assertions failed" >&2
      exit 1
    fi

    if ! grep -F -- '-t input' '${program}' >/dev/null; then
      echo "the sorter must explicitly target CoreAudio input devices" >&2
      exit 1
    fi
    if grep -F -- '-t output' '${program}' >/dev/null; then
      echo "the sorter must never target CoreAudio output devices" >&2
      exit 1
    fi

    state="$TMPDIR/default-input"
    log="$TMPDIR/switch-audio-calls"
    printf '%s\n' fallback > "$state"
    : > "$log"
    SWITCH_AUDIO_SOURCE_BIN='${fakeSwitchAudioSource}' \
      SWITCH_AUDIO_TEST_STATE="$state" \
      SWITCH_AUDIO_TEST_LOG="$log" \
      '${program}' --once --priorities-file '${testPriorities}'

    if [ "$(<"$state")" != preferred ]; then
      echo "the sorter did not choose the highest-priority available input" >&2
      exit 1
    fi
    if grep -F -- '-t output' "$log" >/dev/null; then
      echo "the sorter attempted to inspect or modify an output device" >&2
      exit 1
    fi

    mkdir -p "$out"
    echo "All AudioPriorityBar input sorter regressions passed." > "$out/result"
  ''
