{
  lib,
  rustPlatform,
  fetchFromGitHub,
  rust-jemalloc-sys,
  python3,
}:

rustPlatform.buildRustPackage rec {
  pname = "sqruff";
  version = "0.39.0";

  src = fetchFromGitHub {
    owner = "quarylabs";
    repo = "sqruff";
    rev = "v${version}";
    hash = "sha256-1ynG6A5sGHnCfAfw6MjSTghLPmicRvWPFWnL2Gtns7Y=";
  };

  cargoHash = "sha256-HAeF831rPODaT5nzzq+Li8xEmT78IJiRppaKUSlPXXg=";

  # depends on rust nightly features
  RUSTC_BOOTSTRAP = 1;

  nativeBuildInputs = [ python3 ];
  buildInputs = [ rust-jemalloc-sys ];

  doCheck = false;

  meta = with lib; {
    description = "Fast SQL formatter/linter";
    homepage = "https://github.com/quarylabs/sqruff";
    license = licenses.asl20;
    maintainers = with maintainers; [ edmundmiller ];
    mainProgram = "sqruff";
  };
}
