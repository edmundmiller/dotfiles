inputs: final: prev:
let
  # Reuse the upstream build recipe without upgrading the other agents.
  source = inputs.llm-agents-edge;
  upstream = source.packages.${final.stdenv.hostPlatform.system}.pi;
  buildPkgs = source.inputs.nixpkgs.legacyPackages.${final.stdenv.hostPlatform.system};
  versionData = final.lib.importJSON ./hashes.json;
  fromSource = versionData ? sourceRev;
  # Registry tarballs are immutable per version and npmDepsHash covers the
  # resolved dependencies, so matching pins can use upstream's cached build.
  matchesUpstream =
    !fromSource
    && upstream.version == versionData.version
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
  src =
    if fromSource then
      final.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        rev = versionData.sourceRev;
        hash = versionData.sourceHash;
      }
    else
      final.runCommand "pi-${versionData.version}-src-with-lock" { } ''
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
  modelCatalog = final.fetchurl {
    name = "pi-model-catalog.json";
    url = "https://pi.dev/api/models/revisions/${versionData.modelCatalogRev}?types=chat,image,classifier";
    sha256 = final.lib.removePrefix "sha256-" versionData.modelCatalogRev;
  };
  # The PR's only file with pi's public Desktop-app OAuth client. Fetch it from
  # prHead instead of storing the credential in this repository.
  clientIdentity = final.fetchurl {
    url = "https://raw.githubusercontent.com/earendil-works/pi/${versionData.prHead}/packages/coding-agent/src/core/client-identity.ts";
    hash = versionData.clientIdentityHash;
  };
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
      // final.lib.optionalAttrs fromSource {
        # PR #12614 at prHead, merged onto the release tag at sourceRev.
        patches = [ ./patches/0001-google-ai-plan.patch ];
        postPatch = (old.postPatch or "") + ''
          cp ${clientIdentity} packages/coding-agent/src/core/client-identity.ts
        '';
        npmFlags = [ "--ignore-scripts" ];
        buildPhase = ''
          runHook preBuild
          node ${./prepare-model-catalog.mjs} ${modelCatalog}
          node packages/ai/scripts/hydrate-model-catalog.ts model-catalog.json
          npm run build:offline

          # Feed the existing binary/asset recipe the same layout as a release
          # tarball, but resolve workspace dependencies from this patched build.
          tarball="$(npm pack --workspace packages/coding-agent --ignore-scripts --silent --pack-destination "$TMPDIR")"
          mkdir pi-package
          tar -xzf "$TMPDIR/$tarball" -C pi-package --strip-components=1
          ln -s "$PWD/node_modules" pi-package/node_modules
          cd pi-package
          runHook postBuild
        '';
        installPhase = ''
          runHook preInstall
          runHook postInstall
        '';
      }
      // {
        passthru = (old.passthru or { }) // {
          inherit updater;
        };
      }
    );
  };
}
