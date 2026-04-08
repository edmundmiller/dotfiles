# Build node_modules for pi-packages that have npm dependencies.
# These are symlinked into the mutable pi-packages/ dirs by home-manager
# so that deps are always present without runtime install steps.
#
# To update after changing a package's dependencies:
#   1. cd pi-packages/<pkg> && npm install --package-lock-only --ignore-scripts
#   2. prefetch-npm-deps package-lock.json /tmp/x && nix hash path /tmp/x
#   3. Update the hash below
#   4. hey re
{ pkgs, piPkgsDir }:
let

  # Helper: build node_modules for a pi-package
  mkNodeModules =
    {
      name,
      npmDepsHash,
    }:
    let
      src = pkgs.runCommand "${name}-src" { } ''
        mkdir -p $out
        cp ${piPkgsDir}/${name}/package.json $out/
        cp ${piPkgsDir}/${name}/package-lock.json $out/
      '';
    in
    pkgs.buildNpmPackage {
      pname = "${name}-deps";
      version = "0.0.0";
      inherit src npmDepsHash;
      dontNpmBuild = true;
      # Skip lifecycle scripts (some transitive deps try bunx/etc.)
      npmFlags = [ "--ignore-scripts" ];
      installPhase = ''
        runHook preInstall
        # Wrap in a node_modules/ subdir so Node's symlink-following module
        # resolution can still climb to it (avoids "cannot find module" when
        # packages in the store import hoisted siblings).
        mkdir -p $out/node_modules
        mv node_modules/* $out/node_modules/
        runHook postInstall
      '';
    };
in
{
  pi-agentmap = mkNodeModules {
    name = "pi-agentmap";
    npmDepsHash = "sha256-c5pgY8YERPwnMAuO9LOS5dlgnouSRFv7WDxcvkqNDV8=";
  };

  pi-dcp = mkNodeModules {
    name = "pi-dcp";
    npmDepsHash = "sha256-ECxDBj37SREHyZLdAdrwft5DOQSqJOzzICaC4Mi2KN0=";
  };

  pi-scurl = mkNodeModules {
    name = "pi-scurl";
    npmDepsHash = "sha256-g5j8Mi/MNVnWOVFDV/p2geQYc5OTnz4m/LmArnsQdME=";
  };
}
