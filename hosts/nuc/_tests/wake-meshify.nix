{ nixosConfig, pkgs }:
let
  cfg = nixosConfig.config;
  matches = builtins.filter (
    package: pkgs.lib.getName package == "wake-meshify"
  ) cfg.environment.systemPackages;
  assertions = [
    {
      test = builtins.length matches == 1;
      msg = "NUC must install exactly one wake-meshify command.";
    }
  ];
  failures = builtins.filter (assertion: !assertion.test) assertions;
  package = if failures == [ ] then builtins.head matches else null;
  packagePath = if package == null then "/dev/null" else toString package;
in
pkgs.runCommand "nuc-wake-meshify" { } ''
  if [ ${toString (builtins.length failures)} -ne 0 ]; then
    cat >&2 <<'EOF'
  Wake Meshify assertions failed:
  ${pkgs.lib.concatStringsSep "\n" (map (failure: "- ${failure.msg}") failures)}
  EOF
    exit 1
  fi

  test -x ${packagePath}/bin/wake-meshify
  grep -Fq '192.168.1.255' ${packagePath}/bin/wake-meshify
  grep -Fq 'a8:5e:45:51:a2:e0' ${packagePath}/bin/wake-meshify
  mkdir -p "$out"
  echo "Wake Meshify assertions passed" > "$out/result"
''
