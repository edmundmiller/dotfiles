inputs: final: prev:
let
  # Reuse the upstream build recipe without upgrading the other agents.
  source = inputs.llm-agents-edge;
  upstream = source.packages.${final.stdenv.hostPlatform.system}.pi;
  buildPkgs = source.inputs.nixpkgs.legacyPackages.${final.stdenv.hostPlatform.system};
  versionData = final.lib.importJSON ./hashes.json;
  # Registry tarballs are immutable per version and npmDepsHash covers the
  # resolved dependencies, so matching pins can use upstream's cached build.
  matchesUpstream =
    upstream.version == versionData.version
    && (upstream.npmDepsHash or null) == versionData.npmDepsHash;
  updater = final.writeShellApplication {
    name = "pi-update";
    runtimeInputs = [
      final.python3
      buildPkgs.nodejs_24
      buildPkgs.prefetch-npm-deps
    ];
    text = ''exec python3 ${./update.py} "$@"'';
  };
  src = final.runCommand "pi-${versionData.version}-src-with-lock" { } ''
    mkdir -p $out
    tar -xzf ${
      final.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-coding-agent/-/pi-coding-agent-${versionData.version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    rm -f $out/npm-shrinkwrap.json
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
{
  llm-agents = (prev.llm-agents or { }) // {
    pi = upstream.overrideAttrs (
      old:
      final.lib.optionalAttrs (!matchesUpstream) {
        inherit src;
        inherit (versionData) version npmDepsHash;
        npmDeps = old.npmDeps.overrideAttrs {
          inherit src;
          name = "pi-${versionData.version}-npm-deps";
          outputHash = versionData.npmDepsHash;
        };
      }
      // {
        passthru = (old.passthru or { }) // {
          inherit updater;
        };
      }
    );
  };
}
