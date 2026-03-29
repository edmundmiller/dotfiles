# jsongrep.nix - JSONPath-inspired query language packaged from micahkepe/jsongrep
{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "jsongrep";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "micahkepe";
    repo = "jsongrep";
    rev = "v${version}";
    hash = "sha256-FYXxOjMeGBcEpYMH3zi7lD3QgyAtUiaiLYt4kr0KHvg=";
  };

  cargoHash = "sha256-Anj197PvCEBG9rcm7qzrfpjNKLbs7fa1585G6+HoZ5k=";

  meta = with lib; {
    description = "JSONPath-inspired query language for JSON, YAML, TOML, and other serialization formats";
    homepage = "https://github.com/micahkepe/jsongrep";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "jg";
    platforms = platforms.unix;
  };
}
