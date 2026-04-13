{
  lib,
  rustPlatform,
  fetchFromGitHub,
  rust-jemalloc-sys,
  python3,
}:

rustPlatform.buildRustPackage rec {
  pname = "sqruff";
  version = "0.38.0";

  src = fetchFromGitHub {
    owner = "quarylabs";
    repo = "sqruff";
    rev = "v${version}";
    hash = "sha256-khIP3CtrWcMWIuLcKwDOhwfnJ2FfpffQNqphNpWtzOs=";
  };

  cargoHash = "sha256-9u8U7rWm6jOlxky8+y4ptPRnBBEBWWcg4QO0jbLAk5E=";

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
