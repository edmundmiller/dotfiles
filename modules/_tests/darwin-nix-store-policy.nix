# Pure Darwin assertion: retain enough disk headroom for Nix to recover safely.
{
  macTraitorConfig,
  seqeratopConfig,
  pkgs,
}:
let
  inherit (builtins) filter length;

  gib = 1024 * 1024 * 1024;
  expected = {
    minFree = 20 * gib;
    maxFree = 40 * gib;
    reserved = 2 * gib;
  };

  hostAssertions =
    name: host:
    let
      inherit (host) config;
      settings = config.nix.settings;
      interval = config.nix.gc.interval;
      minFree = settings."min-free" or 0;
      maxFree = settings."max-free" or 0;
      reserved = settings."gc-reserved-space" or 0;
    in
    [
      {
        test = builtins.isInt minFree && minFree >= expected.minFree;
        msg = "${name} must trigger Nix GC with at least 20 GiB still free";
      }
      {
        test = builtins.isInt maxFree && maxFree >= expected.maxFree;
        msg = "${name} must recover to at least a 40 GiB Nix free-space target";
      }
      {
        test = builtins.isInt reserved && reserved >= expected.reserved;
        msg = "${name} must reserve at least 2 GiB for a disk-pressure GC transaction";
      }
      {
        test =
          builtins.isInt reserved
          && builtins.isInt minFree
          && builtins.isInt maxFree
          && 0 < reserved
          && reserved < minFree
          && minFree < maxFree;
        msg = "${name} Nix disk thresholds must remain ordered";
      }
      {
        test = config.nix.gc.automatic or false;
        msg = "${name} must keep automatic Nix garbage collection enabled";
      }
      {
        test =
          interval.Hour == 2
          && interval.Minute == 0
          && (interval.Day or null) == null
          && (interval.Month or null) == null
          && (interval.Weekday or null) == null;
        msg = "${name} must run Nix GC daily at 02:00";
      }
      {
        test = config.nix.gc.options == "--delete-older-than 7d";
        msg = "${name} must retain the bounded seven-day Nix history";
      }
      {
        test = config.nix.optimise.automatic or false;
        msg = "${name} must keep automatic Nix store optimisation enabled";
      }
    ];

  assertions =
    (hostAssertions "MacTraitor-Pro" macTraitorConfig) ++ (hostAssertions "Seqeratop" seqeratopConfig);
  failures = filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "darwin-nix-store-policy"
  {
    passthru = { inherit assertions failures; };
  }
  ''
    if [ ${toString (length failures)} -ne 0 ]; then
      echo "${toString (length failures)} Darwin Nix store policy assertions failed" >&2
      exit 1
    fi
    mkdir -p "$out"
    echo "All Darwin Nix store policy assertions passed." > "$out/result"
  ''
