# Pure Nix/build test: MacTraitor-Pro wires DJI receiver button → Raycast chord.
{
  darwinConfig,
  pkgs,
}:
let
  inherit (builtins) filter length;
  inherit (pkgs.lib.strings) hasInfix;

  mac = darwinConfig.config;
  rule = builtins.fromJSON (
    builtins.readFile ../../../config/karabiner/dji-mic-raycast-dictation.json
  );
  manipulator = builtins.elemAt (builtins.elemAt rule.rules 0).manipulators 0;
  toEvent = builtins.elemAt manipulator.to 0;
  identifier = builtins.elemAt (builtins.elemAt manipulator.conditions 0).identifiers 0;
  dictationAsset = ".config/karabiner/assets/complex_modifications/dji-mic-raycast-dictation.json";
  muteAsset = ".config/karabiner/assets/complex_modifications/dji-mic-mini-receiver-mute.json";
  installedSource = mac.home.file.${dictationAsset}.source or "";

  assertions = [
    {
      test = mac.modules.desktop.apps.djiMicMiniRaycastDictation.enable;
      msg = "MacTraitor-Pro must enable DJI Mic Mini Raycast dictation";
    }
    {
      test = !mac.modules.desktop.apps.djiMicMiniReceiverMute.enable;
      msg = "MacTraitor-Pro must not also enable the receiver-mute mapping on the same button";
    }
    {
      test = mac.modules.desktop.apps.raycast.enable;
      msg = "Raycast must stay enabled so dictation is the installed launcher";
    }
    {
      test = hasInfix "dji-mic-raycast-dictation.json" (toString installedSource);
      msg = "Home Manager must install the receiver-scoped Karabiner dictation asset";
    }
    {
      test = !(mac.home.file ? ${muteAsset});
      msg = "the mute Karabiner asset must not be installed while dictation owns the button";
    }
    {
      test = manipulator.from.consumer_key_code == "volume_increment";
      msg = "the rule must match Consumer Control volume increment (0x0C/0xE9)";
    }
    {
      test = identifier.vendor_id == 11427 && identifier.product_id == 16401 && identifier.is_consumer;
      msg = "the rule must match only the DJI mobile receiver consumer interface";
    }
    {
      test = toEvent.key_code == "spacebar";
      msg = "the emitted chord must include Space";
    }
    {
      test = toEvent.modifiers == [
        "left_control"
        "left_option"
        "left_command"
      ];
      msg = "the emitted chord must be Ctrl+Option+Command (Bedesqui C-A-M-spc)";
    }
    {
      test = toEvent.hold_down_milliseconds == 120 && toEvent.repeat == false;
      msg = "the chord must be held 120 ms without key repeat";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "dji-mic-raycast-dictation-regressions"
  {
    passthru = {
      inherit assertions failures;
    };
  }
  ''
    if [ ${toString (length failures)} -ne 0 ]; then
      echo "${toString (length failures)} DJI Mic Mini Raycast dictation assertions failed" >&2
      exit 1
    fi
    mkdir -p "$out"
    echo "DJI Mic Mini Raycast dictation wiring OK." > "$out/result"
  ''
