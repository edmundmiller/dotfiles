{
  lib,
  rustPlatform,
  fetchFromGitHub,
  gh,
  makeWrapper,
}:

rustPlatform.buildRustPackage {
  pname = "jj-forklift";
  version = "0-unstable-2026-07-10";

  src = fetchFromGitHub {
    owner = "rivet-dev";
    repo = "jj-forklift";
    rev = "f1d50a5c8af22c42ae17c5a0d10b7db8ee6b2758";
    hash = "sha256-UPkdgU8l23LS12nVCFGX2b7DUJY95UYFv9xMLnOK1CM=";
  };

  cargoHash = "sha256-YptPd3AzONuSEECdPg40QY++7U0tNVTROekKQgsJqbI=";

  nativeBuildInputs = [ makeWrapper ];

  # Upstream integration tests are pinned to older jj CLI behavior.
  cargoTestFlags = [ "--lib" ];

  # Upstream derives build metadata from .git. Nix builds from a source archive.
  VERGEN_IDEMPOTENT = "1";

  postInstall = ''
    wrapProgram $out/bin/forklift \
      --prefix PATH : ${lib.makeBinPath [ gh ]}
  '';

  meta = with lib; {
    description = "Jujutsu-native collaborative stacked pull request workflow";
    homepage = "https://github.com/rivet-dev/jj-forklift";
    license = licenses.asl20;
    maintainers = [ ];
    mainProgram = "forklift";
    platforms = platforms.unix;
  };
}
