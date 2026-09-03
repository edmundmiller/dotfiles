{ pkgs }:
let
  profileNames = [
    "amosburton"
    "anne"
    "betty"
    "finn"
    "orchestrator"
    "scintillate"
  ];
in
pkgs.runCommand "nuc-hermes-displayctl-wiring" { } ''
  if ! grep -Fq 'DISPLAYCTL_CONFIG=' ${../default.nix}; then
    echo "NUC must declare the DISPLAYCTL_CONFIG assignment in its shared Hermes environment file." >&2
    exit 1
  fi

  if ! grep -Pzq 'withHermesDisplayctl =\n    profile:\n    profile\n    // \{\n      extraPackages = \[\n        pkgs\.my\.buzz\n        pkgs\.my\.displayctl' ${../default.nix}; then
    echo "NUC's Hermes profile wrapper must include the displayctl package." >&2
    exit 1
  fi

  for profile in ${builtins.concatStringsSep " " profileNames}; do
    if ! grep -Fq "$profile = withHermesDisplayctl" ${../default.nix}; then
      echo "Hermes profile $profile must use the host's displayctl-wiring profile wrapper." >&2
      exit 1
    fi
  done

  mkdir -p "$out"
  echo "All NUC Hermes displayctl wiring assertions passed." > "$out/result"
''
