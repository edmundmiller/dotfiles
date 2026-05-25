{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  git,
  makeWrapper,
}:

buildNpmPackage rec {
  pname = "codegraph";
  version = "0.9.4";

  src = fetchFromGitHub {
    owner = "colbymchenry";
    repo = "codegraph";
    # Upstream has not tagged 0.9.4 yet; pin the main commit that declares
    # package.json version 0.9.4.
    rev = "f366222dbd6b7e43047072a9417289b1b02ae457";
    hash = "sha256-R7Qdu+Xi1yA/yWTM+3TacRC03i2mJ+GCbUnIcE08BtI=";
  };

  npmDepsHash = "sha256-smRuRtQATONIKz71imQEYoXBfCSnc40GoVK+Op/IDnc=";
  npmDepsFetcherVersion = 2;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/codegraph \
      --prefix PATH : ${lib.makeBinPath [ git ]}
  '';

  meta = {
    description = "Semantic code intelligence for AI coding agents";
    homepage = "https://github.com/colbymchenry/codegraph";
    license = lib.licenses.mit;
    mainProgram = "codegraph";
    platforms = lib.platforms.all;
  };
}
