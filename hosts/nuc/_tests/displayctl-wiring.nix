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
  inherit (pkgs.lib) hasInfix;
  hostSource = builtins.readFile ../default.nix;

  assertions = [
    {
      test = hasInfix "DISPLAYCTL_CONFIG=" hostSource;
      msg = "NUC must declare the DISPLAYCTL_CONFIG assignment in its shared Hermes environment file.";
    }
    {
      test = hasInfix "extraPackages = [ pkgs.my.displayctl ]" hostSource;
      msg = "NUC's Hermes profile wrapper must prepend the displayctl package.";
    }
  ]
  ++ map (name: {
    test = hasInfix "${name} = withHermesDisplayctl" hostSource;
    msg = "Hermes profile ${name} must use the host's displayctl-wiring profile wrapper.";
  }) profileNames;
  failures = builtins.filter (assertion: !assertion.test) assertions;
  failureText = builtins.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures);
in
pkgs.runCommand "nuc-hermes-displayctl-wiring" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  NUC Hermes displayctl wiring assertions failed:
  ${failureText}
  EOF
    exit 1
  fi

  mkdir -p "$out"
  echo "All ${toString (builtins.length assertions)} NUC Hermes displayctl wiring assertions passed." > "$out/result"
''
