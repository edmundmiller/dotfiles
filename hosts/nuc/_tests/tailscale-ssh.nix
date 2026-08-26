{ nixosConfig, pkgs }:
let
  flags = nixosConfig.config.services.tailscale.extraSetFlags;
  count = flag: builtins.length (builtins.filter (candidate: candidate == flag) flags);
  assertions = [
    {
      test = count "--ssh" == 1;
      msg = "NUC must advertise Tailscale SSH exactly once.";
    }
    {
      test = count "--advertise-routes=192.168.1.0/24" == 1;
      msg = "NUC must preserve its LAN subnet advertisement.";
    }
    {
      test = count "--operator=emiller" == 1;
      msg = "NUC must preserve emiller as the Tailscale operator.";
    }
  ];
  failures = builtins.filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "nuc-tailscale-ssh" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  NUC Tailscale SSH assertions failed:
  ${builtins.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
  EOF
    exit 1
  fi

  touch "$out"
''
