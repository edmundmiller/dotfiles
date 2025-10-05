{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  openssl,
  zlib,
}:
rustPlatform.buildRustPackage rec {
  pname = "jj-spr";
  version = "unstable-2025-01-10";

  src = fetchFromGitHub {
    owner = "LucioFranco";
    repo = "jj-spr";
    rev = "8f2eb88a4fae08784cba4c0d72ff22eab348822f";
    hash = "sha256-I51IGIQ5J7xv5SU+BVafQQv0mocCgSwliElZuhlL0lY=";
  };

  cargoHash = "sha256-bAWDwWSZWeegeJ7DY/PyCWQ9oYMn9A+PLAGkkmwzd8A=";

  # The binary is in the spr/ subdirectory, but Cargo.lock is in the root
  buildAndTestSubdir = "spr";

  # Skip tests as they require jj binary in PATH
  doCheck = false;

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
    zlib
  ];

  meta = with lib; {
    description = "A command-line tool for submitting and updating GitHub Pull Requests from local Jujutsu commits";
    homepage = "https://github.com/LucioFranco/jj-spr";
    license = licenses.mit;
    mainProgram = "jj-spr";
    maintainers = with maintainers; [ edmundmiller ];
  };
}
