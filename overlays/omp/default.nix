final: prev: {
  llm-agents = (prev.llm-agents or { }) // {
    omp = prev.llm-agents.omp.overrideAttrs (
      old:
      let
        version = "18.0.3";
        src = final.applyPatches {
          src = final.fetchFromGitHub {
            owner = "can1357";
            repo = "oh-my-pi";
            tag = "v${version}";
            hash = "sha256-0ybJ+7WFtXWpVkd4p7ko3T222WX903U9brFY1oKdRHM=";
          };
          patches = [
            ./patches/0001-add-herdr-hunk-internal-urls.patch
            ./patches/0002-add-nextflow-ast-grep-language.patch
          ];
        };
      in
      {
        inherit version src;
        # v18.0.3 uses audiopus_sys with static linkage, unlike the newer
        # codec dependency in the inherited package's native build inputs.
        buildInputs = (old.buildInputs or [ ]) ++ [
          (final.libopus.overrideAttrs (opusOld: {
            mesonFlags = (opusOld.mesonFlags or [ ]) ++ [ "-Ddefault_library=both" ];
          }))
        ];
        # v18.0.3 validates a compiled version-sentinel export, not the
        # post-link stamp introduced by the newer inherited package.
        buildPhase =
          final.lib.replaceStrings
            [ "bun scripts/stamp-native-version.ts" ]
            [ "test ! -f scripts/stamp-native-version.ts || bun scripts/stamp-native-version.ts" ]
            old.buildPhase;
        cargoDeps = final.rustPlatform.fetchCargoVendor {
          name = "omp-${version}-cargo-vendor";
          inherit src;
          hash = "sha256-k3VnG2Vx44krJkCtcFnXICmX6wn3mEQBetKgIBOU9GU=";
        };
        bunDeps = final.bun2nix.fetchBunDeps {
          bunNix = ./bun.nix;
        };
        postInstall =
          (old.postInstall or "")
          + final.lib.optionalString final.stdenv.hostPlatform.isDarwin ''
            for binary in "$out/lib/omp/omp" "$out"/lib/omp/pi_natives.*.node; do
              [ -e "$binary" ] && /usr/bin/codesign -f -s - "$binary"
            done
          '';
      }
    );
  };
}
