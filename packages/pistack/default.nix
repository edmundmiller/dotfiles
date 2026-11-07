{
  fetchFromGitHub,
  git,
  lib,
  nodejs,
  stdenvNoCC,
}:
let
  upstream = builtins.fromJSON (builtins.readFile ./package-harness.json);
in
stdenvNoCC.mkDerivation {
  pname = "pistack";
  version = "unstable-${builtins.substring 0 7 upstream.ref}";

  src = fetchFromGitHub {
    owner = "cursor";
    repo = "plugins";
    rev = upstream.ref;
    hash = "sha256-YB+9AIZJ6aR5Yx1OC22Xc6HdoxvDDjja/z2yMUt5gWs=";
  };

  patches = map (patch: ./. + "/${patch}") upstream.patches;
  nativeBuildInputs = [
    git
    nodejs
  ];

  # git apply rejects changed context rather than applying patches with fuzz.
  patchPhase = ''
    runHook prePatch
    for patch in $patches; do
      git apply --check "$patch"
      git apply "$patch"
    done
    runHook postPatch
  '';

  dontBuild = true;
  dontPatchShebangs = true;
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    PSTACK_SOURCE="$PWD" node --test ${./.}/build.test.mjs
    runHook postCheck
  '';
  installPhase = ''
    runHook preInstall
    node ${./build.mjs} "$PWD" "$out" ${./PI.md}
    runHook postInstall
  '';

  meta = {
    description = "Upstream pstack skills with checked, local Pi compatibility patches";
    homepage = "https://github.com/cursor/plugins/tree/main/pstack";
    license = lib.licenses.mit;
    platforms = lib.platforms.unix;
  };
}
