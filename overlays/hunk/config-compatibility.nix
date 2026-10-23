{ inputs, pkgs }:
let
  hunkPackage = import ./package.nix { inherit inputs pkgs; };
in
hunkPackage.overrideAttrs (old: {
  pname = "hunk-config-compatibility";
  postPatch = (old.postPatch or "") + ''
    cp ${./config-compatibility.test.ts} config-compatibility.test.ts
    cp ${./package.test.ts} package.test.ts
    mkdir -p test/jev-priority
    cp ${../../config/hunk/jev-priority.ts} test/jev-priority/jev-priority.ts
    cp ${../../config/hunk/jev-priority.test.ts} test/jev-priority/jev-priority.test.ts
  '';
  checkPhase = (old.checkPhase or "") + ''
    runHook preCheck
    export HOME="$TMPDIR/hunk-compatibility-home"
    export HUNK_TEST_EXTENSIONS=${hunkPackage.extensions}
    mkdir -p "$HOME/.config/hunk"
    cp ${../../config/hunk/config.toml} "$HOME/.config/hunk/config.toml"
    chmod -R u+w "$HOME"
    "$bun_compiler" test config-compatibility.test.ts test/jev-priority/jev-priority.test.ts
    runHook postCheck
  '';
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    for executable in hunk hunkdiff; do
      HUNK_TEST_EXECUTABLE="$out/bin/$executable" "$bun_compiler" test ./package.test.ts
    done
    runHook postInstallCheck
  '';
})
