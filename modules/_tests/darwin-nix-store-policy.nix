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
    in
    [
      {
        test = (settings."min-free" or null) == expected.minFree;
        msg = "${name} must trigger Nix GC with 20 GiB still free";
      }
      {
        test = (settings."max-free" or null) == expected.maxFree;
        msg = "${name} must recover to a 40 GiB Nix free-space target";
      }
      {
        test = (settings."gc-reserved-space" or null) == expected.reserved;
        msg = "${name} must reserve 2 GiB for a disk-pressure GC transaction";
      }
      {
        test =
          0 < expected.reserved
          && expected.reserved < expected.minFree
          && expected.minFree < expected.maxFree;
        msg = "${name} Nix disk thresholds must remain ordered";
      }
      {
        test = config.nix.gc.automatic or false;
        msg = "${name} must keep automatic Nix garbage collection enabled";
      }
      {
        test =
          interval == {
            Hour = 2;
            Minute = 0;
          };
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
