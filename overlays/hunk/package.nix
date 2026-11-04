{ inputs, pkgs }:
let
  metadata = builtins.fromJSON (builtins.readFile ./package-harness.json);
  patches = map (patch: ./. + "/${patch}") metadata.patches;
  extensions = pkgs.runCommand "hunk-extensions" { } ''
    mkdir -p $out
    # Hunk's directory scan requires real subdirectories, not directory symlinks.
    cp -R ${inputs.hunk-commit-log} $out/hunk-commit-log
    cp ${../../config/hunk/jev-priority.ts} $out/jev-priority.ts
  '';
in
inputs.hunk.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (
  finalAttrs: old: {
    patches = (old.patches or [ ]) ++ patches;
    nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [
      pkgs.git
      pkgs.jujutsu
    ];
    doCheck = true;
    disabledTests = [
      # Sapling is not provisioned here. Keep Git/Jujutsu loader coverage enabled.
      "sl reviews ignore generated Git attributes with either override choice"
      "includes Sapling unknown files in working copy reviews"
    ];
    # Bun has no disabledTests hook: translate literal names into its name filter.
    bunCheckFlags = pkgs.lib.optionals (finalAttrs.disabledTests != [ ]) [
      "--test-name-pattern"
      (
        "^(?!.*(?:" + pkgs.lib.concatMapStringsSep "|" pkgs.lib.escapeRegex finalAttrs.disabledTests + ")$)"
      )
    ];
    checkPhase = ''
      runHook preCheck
      export HOME="$TMPDIR/hunk-check-home"
      export GIT_CONFIG_GLOBAL=/dev/null JJ_CONFIG=/dev/null
      mkdir -p "$HOME"
      "$bun_compiler" test ./packages/hunk/src/core/changeset/loaders.test.ts ${pkgs.lib.escapeShellArgs finalAttrs.bunCheckFlags}
      runHook postCheck
    '';
    # These are disk-loaded user extensions, not Hunk's compiled-in capabilities.
    # Keep stable entry names for IDs/config and honor --no-extensions normally.
    postInstall = (old.postInstall or "") + ''
      mkdir -p $out/share/hunk
      ln -s ${extensions} $out/share/hunk/extensions
      wrapProgram $out/bin/hunk --run ${pkgs.lib.escapeShellArg ''
        # Match Hunk's leading bootstrap flags without consuming the caller's argv.
        # Other built-ins reject extension flags and never load extensions.
        hunk_load_extensions=true
        hunk_skip_value=false
        for hunk_arg in "$@"; do
          if "$hunk_skip_value"; then
            hunk_skip_value=false
            continue
          fi
          case "$hunk_arg" in
            --extension|--disable-extension|--enable-extension)
              hunk_skip_value=true ;;
            --extension=*|--disable-extension=*|--enable-extension=*|--no-extensions|--fast|--experimental)
              ;;
            open|session|markup|skill|extension|ext|update|completion|daemon|mcp)
              hunk_load_extensions=false
              break ;;
            *) break ;;
          esac
        done
        if "$hunk_load_extensions"; then
          set -- --extension ${extensions} "$@"
        fi
      ''}
    '';
    passthru = (old.passthru or { }) // {
      inherit extensions;
    };
  }
)
