# Pure Nix/build regression: keep the input sorter continuous and input-only.
{
  darwinConfig,
  pkgs,
}:
let
  inherit (builtins) filter length;
  inherit (pkgs.lib.strings) hasInfix;

  mac = darwinConfig.config;
  activation = mac.home-manager.users.${mac.user.name}.home.activation.audioPriorityBarDefaults.data;
  launchAgent = mac.launchd.user.agents."audio-priority-bar";
  service = launchAgent.serviceConfig;
  program = service.Program;

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
      test = !hasInfix "name:Razer Seiren V3 Mini" activation;
      msg = "the UID-only GUI must not receive the sorter's name selectors";
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
  ];

  failures = filter (assertion: !assertion.test) assertions;

  fakeSwitchAudioSource = pkgs.writeShellScript "fake-switch-audio-source" ''
    set -euo pipefail
    state="''${SWITCH_AUDIO_TEST_STATE:?}"
    log="''${SWITCH_AUDIO_TEST_LOG:?}"
    printf '%s\n' "$*" >> "$log"

    if [[ "$*" == "-a -t input -f json" ]]; then
      if [[ -n "''${SWITCH_AUDIO_TEST_DEVICES:-}" ]]; then
        cat "$SWITCH_AUDIO_TEST_DEVICES"
        exit 0
      fi
      printf '%s\n' \
        '{"name":"Fallback","type":"input","uid":"fallback"}' \
        '{"name":"Preferred","type":"input","uid":"preferred"}'
      exit 0
    fi
    if [[ "$*" == "-c -t input -f json" ]]; then
      uid="$(<"$state")"
      ${pkgs.jq}/bin/jq -n --arg uid "$uid" '{name: "Current input", type: "input", uid: $uid}'
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

  nameTestPriorities = pkgs.writeText "audio-input-name-priority-test-list" ''
    dji
    shure
    name:Razer Seiren V3 Mini
    fallback
  '';
in
pkgs.runCommand "audio-priority-bar-regressions"
  {
    nativeBuildInputs = [ pkgs.jq ];
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

    devices="$TMPDIR/input-devices"
    run_name_case() {
      local initial="$1" expected="$2"
      printf '%s\n' "$initial" > "$state"
      SWITCH_AUDIO_SOURCE_BIN='${fakeSwitchAudioSource}' \
        SWITCH_AUDIO_TEST_STATE="$state" \
        SWITCH_AUDIO_TEST_LOG="$log" \
        SWITCH_AUDIO_TEST_DEVICES="$devices" \
        '${program}' --once --priorities-file '${nameTestPriorities}'
      if [ "$(<"$state")" != "$expected" ]; then
        echo "expected input $expected, got $(<"$state")" >&2
        exit 1
      fi
    }

    # A matching model at either unknown USB location must beat the fallback.
    # A similarly named device must never match the exact model selector.
    for uid in port-z port-a; do
      jq -n --arg uid "$uid" '
        {name: "Fallback", type: "input", uid: "fallback"},
        {name: "Razer Seiren V3 Mini Extra", type: "input", uid: "decoy"},
        {name: "Razer Seiren V3 Mini", type: "input", uid: $uid}
      ' > "$devices"
      run_name_case fallback "$uid"
    done

    # Duplicate models keep the selected mic, otherwise choose consistently.
    echo '{"name":"Razer Seiren V3 Mini","type":"input","uid":"port-z"}' >> "$devices"
    run_name_case port-z port-z
    run_name_case fallback port-a
    jq -s 'reverse[]' "$devices" > "$devices.reversed"
    mv "$devices.reversed" "$devices"
    run_name_case fallback port-a

    # Exact UID priorities still outrank the name selector.
    echo '{"name":"Shure","type":"input","uid":"shure"}' >> "$devices"
    run_name_case port-a shure
    echo '{"name":"DJI","type":"input","uid":"dji"}' >> "$devices"
    run_name_case shure dji

    echo '{"name":"Razer Seiren V3 Mini Extra","type":"input","uid":"decoy"}' > "$devices"
    echo '{"name":"Fallback","type":"input","uid":"fallback"}' >> "$devices"
    run_name_case decoy fallback
    echo '{"name":"Unlisted","type":"input","uid":"unlisted"}' > "$devices"
    run_name_case unlisted unlisted

    if grep -F -- '-t output' "$log" >/dev/null; then
      echo "the sorter attempted to inspect or modify an output device" >&2
      exit 1
    fi

    mkdir -p "$out"
    echo "All AudioPriorityBar input sorter regressions passed." > "$out/result"
  ''
