# Pure Nix/build test: keep the Apple Container pilot scoped to MacTraitor-Pro.
{
  macTraitorConfig,
  seqeratopConfig,
  pkgs,
}:
let
  inherit (builtins) filter isAttrs length;
  inherit (pkgs.lib) any;
  inherit (pkgs.lib.strings) hasInfix;

  personal = macTraitorConfig.config;
  work = seqeratopConfig.config;

  itemName = item: if isAttrs item then (item.name or "") else item;
  hasCask = name: host: any (cask: itemName cask == name) (host.homebrew.casks or [ ]);

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
      test = hasCask "orchard" personal;
      msg = "MacTraitor-Pro must declare the Homebrew orchard cask";
    }
    {
      test = hasCask "orbstack" personal;
      msg = "MacTraitor-Pro must declare OrbStack as the Docker-compatible provider";
    }
    {
      test =
        (personal.modules.services.containers.enable or false)
        && (personal.modules.services.containers.provider or null) == "orbstack"
        && (personal.env.DOCKER_CONTEXT or null) == "orbstack";
      msg = "MacTraitor-Pro must use OrbStack for Docker-compatible tooling";
    }
    {
      test = any (
        path: hasInfix "config/docker/aliases.zsh" (toString path)
      ) personal.modules.shell.zsh.rcFiles;
      msg = "MacTraitor-Pro must expose the OrbStack-compatible shell aliases";
    }
    {
      test = personal.environment.shellAliases ? dcup;
      msg = "MacTraitor-Pro must expose Compose shell aliases for OrbStack consumers";
    }
    {
      test = !(work.modules.services.appleContainer.enable or false);
      msg = "Seqeratop must not enable the Apple Container pilot";
    }
    {
      test = !(hasCask "orchard" work);
      msg = "Seqeratop must not declare the Homebrew orchard cask";
    }
    {
      test = hasCask "orbstack" work;
      msg = "Seqeratop must declare OrbStack as the Docker-compatible provider";
    }
    {
      test =
        (work.modules.services.containers.enable or false)
        && (work.modules.services.containers.provider or null) == "orbstack"
        && (work.env.DOCKER_CONTEXT or null) == "orbstack";
      msg = "Seqeratop must use OrbStack for Docker-compatible tooling";
    }
    {
      test =
        any (path: hasInfix "config/docker/aliases.zsh" (toString path)) work.modules.shell.zsh.rcFiles
        && work.environment.shellAliases ? dcup;
      msg = "Seqeratop must expose OrbStack-compatible shell aliases";
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
