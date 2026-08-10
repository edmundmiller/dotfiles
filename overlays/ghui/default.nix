# ghui overlay.
#
# Upstream `kitlangton/ghui` exposes only a devShell from its flake, so the
# package is built here from the `ghui` flake input's source. That input is
# pinned to the head of PR #43 (diff hunk navigation and copy); see
# package-harness.json.
inputs: final: prev:

let
  inherit (prev) lib;
  bun2nix = inputs.bun2nix.packages.${final.stdenv.hostPlatform.system}.default;

  # bun.nix references the `@ghui/keymap` workspace package as a path relative
  # to itself, so it is placed inside the source tree where that relative path
  # resolves.
  #
  # TODO: pin upstream `kitlangton/ghui` and apply the PR #43 delta as an
  # in-tree patch here instead, so we can carry our own changes on top rather
  # than being limited to whatever is on the fork's branch.
  src = final.runCommand "ghui-source" { } ''
    cp -r ${inputs.ghui} $out
    chmod -R u+w $out
    cp ${./bun.nix} $out/bun.nix
  '';

  ghui = final.stdenv.mkDerivation {
    pname = "ghui";
    version = "0.7.1";

    inherit src;

    nativeBuildInputs = [
      bun2nix.hook
      final.makeWrapper
    ];

    bunDeps = bun2nix.fetchBunDeps {
      bunNix = "${src}/bun.nix";
    };

    buildPhase = ''
      runHook preBuild
      bun build --compile --bytecode --format=esm \
        --outfile=ghui src/standalone.ts
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      install -Dm755 ghui $out/bin/ghui
      ${lib.optionalString final.stdenv.hostPlatform.isDarwin ''
        chmod u+w $out/bin/ghui
        /usr/bin/codesign -f -s - $out/bin/ghui
      ''}
      wrapProgram $out/bin/ghui --prefix PATH : ${lib.makeBinPath [ final.gh ]}

      runHook postInstall
    '';

    meta = {
      description = "Terminal UI for GitHub pull requests";
      homepage = "https://github.com/kitlangton/ghui";
      license = lib.licenses.mit;
      mainProgram = "ghui";
    };
  };
in
{
  my = (prev.my or { }) // { inherit ghui; };
}
