{ nixosConfig, pkgs }:
let
  service = nixosConfig.config.systemd.services.hermes-scintillate-desktop-dashboard;
  assertions = [
    {
      test = service.enable;
      msg = "Scintillate's Desktop dashboard must remain enabled so auto-upgrades do not mask it.";
    }
    {
      test = builtins.elem "multi-user.target" service.wantedBy;
      msg = "Scintillate's Desktop dashboard must start from multi-user.target after every NUC activation.";
    }
  ];
  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-hermes-dashboard-enabled" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  NUC Hermes Desktop dashboard assertions failed:
  ${builtins.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
  EOF
    exit 1
  fi

  touch "$out"
''
