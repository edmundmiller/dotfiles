# Pure Nix/build test: keep the Apple Container pilot scoped to MacTraitor-Pro.
{
  macTraitorConfig,
  seqeratopConfig,
  pkgs,
}:
let
  inherit (builtins) filter length;
  inherit (pkgs.lib) any;
  inherit (pkgs.lib.strings) hasInfix;

  personal = macTraitorConfig.config;
  work = seqeratopConfig.config;

  assertions = [
    {
      test = personal.modules.services.appleContainer.enable or false;
      msg = "MacTraitor-Pro must enable the local Apple Container module";
    }
    {
      test = personal.services.containerization.enable or false;
      msg = "MacTraitor-Pro must enable the upstream Apple Container runtime";
    }
    {
      test = !(personal.modules.services.docker.enable or false);
      msg = "MacTraitor-Pro must not install Docker tooling through Nix";
    }
    {
      test =
        !any (
          path: hasInfix "config/docker/aliases.zsh" (toString path)
        ) personal.modules.shell.zsh.rcFiles;
      msg = "MacTraitor-Pro must not load Docker zsh aliases";
    }
    {
      test = !(personal.environment.shellAliases ? dcup);
      msg = "MacTraitor-Pro must not expose Docker Compose shell aliases";
    }
    {
      test = !(work.modules.services.appleContainer.enable or false);
      msg = "Seqeratop must not enable the Apple Container pilot";
    }
    {
      test = work.modules.services.docker.enable or false;
      msg = "Seqeratop must retain its Nix-managed Docker tooling";
    }
    {
      test =
        any (path: hasInfix "config/docker/aliases.zsh" (toString path)) work.modules.shell.zsh.rcFiles
        && work.environment.shellAliases ? dcup;
      msg = "Seqeratop must retain its Docker shell aliases";
    }
  ];

  failures = filter (assertion: !assertion.test) assertions;
in
pkgs.runCommand "apple-container-pilot-assertions"
  {
    passthru = { inherit assertions failures; };
  }
  ''
    if [ ${toString (length failures)} -ne 0 ]; then
      echo "${toString (length failures)} Apple Container pilot assertions failed" >&2
      exit 1
    fi
    mkdir -p "$out"
    echo "All Apple Container pilot assertions passed." > "$out/result"
  ''
