{
  lib,
  rustPlatform,
  fetchFromGitHub,
  rust-jemalloc-sys,
}:

rustPlatform.buildRustPackage rec {
  pname = "sqruff";
  version = "0.11.1";

  src = fetchFromGitHub {
    owner = "quarylabs";
    repo = "sqruff";
    rev = "v${version}";
    hash = "sha256-tAnfkeDou6OLTd9jnGxqLu8ydB8vTa+MQ7utCcua7zQ=";
  };

  cargoHash = "sha256-A5csnVtUDmxFn7uBY2tBsZaTiYBZfF3jtAuly+tzrFs=";

  # depends on rust nightly features
  RUSTC_BOOTSTRAP = 1;

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
