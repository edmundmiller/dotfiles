# Pure Nix/build regression: capture the broken AudioPriorityBar deployment.
{
  darwinConfig,
  pkgs,
}:
let
  inherit (builtins) filter length;
  inherit (pkgs.lib.strings) hasInfix;

  mac = darwinConfig.config;
  activation = mac.home-manager.users.${mac.user.name}.home.activation.audioPriorityBarDefaults.data;
  launchAgent = mac.launchd.user.agents."audio-priority-bar" or null;

  expectedFailures = [
    {
      reproduced = hasInfix "/usr/bin/defaults write app.audioprioritybar" activation;
      msg = "the activation writes a defaults domain the app does not read";
    }
    {
      reproduced = launchAgent == null;
      msg = "the enabled app has no continuously running launch agent";
    }
    {
      reproduced = !(mac.modules.desktop.apps.audioPriorityBar ? manageOutputs);
      msg = "the module cannot disable automatic output-device changes";
    }
  ];

  unexpectedPasses = filter (failure: !failure.reproduced) expectedFailures;
in
pkgs.runCommand "audio-priority-bar-regressions"
  {
    passthru = {
      inherit expectedFailures unexpectedPasses;
    };
  }
  ''
    if [ ${toString (length unexpectedPasses)} -ne 0 ]; then
      echo "${toString (length unexpectedPasses)} AudioPriorityBar expected failures unexpectedly passed" >&2
      exit 1
    fi
    mkdir -p "$out"
    echo "All AudioPriorityBar regressions reproduced as strict expected failures." > "$out/result"
  ''
