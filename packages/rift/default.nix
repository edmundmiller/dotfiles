{
  lib,
  rustPlatform,
  fetchFromGitHub,
  git,
}:

rustPlatform.buildRustPackage {
  pname = "rift";
  version = "0.0.10-unstable-2026-06-03";

  src = fetchFromGitHub {
    owner = "anomalyco";
    repo = "rift";
    rev = "18ca9d199cfa0033e1adf63b1eb6625fab89478a";
    hash = "sha256-/BBheYewi8jI6J/KcGZaG/SWNcvAH1mOf2QMVQKI0bM=";
  };

  cargoHash = "sha256-JdIPIun3d5HURgX7m/HOspj5DJoLI6N8C1lmvvDVU4I=";

  nativeCheckInputs = [ git ];

  meta = with lib; {
    description = "Copy-on-write workspace snapshots";
    homepage = "https://github.com/anomalyco/rift";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "rift";
    platforms = [
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
    ];
  };
}
